// NSXPCListenerDelegate for the wallpaper extension's XPC service.
//
// Accepts connections from WallpaperAgent, sets up the exported interface
// with all required WallpaperExtensionKit class whitelists, and creates
// the WallpaperXPCHandler to process incoming messages.

import Foundation

final class ExtensionXPCDelegate: NSObject, NSXPCListenerDelegate {
    /// Retain the accepted connection — NSXPCListener does NOT retain it.
    private var connection: NSXPCConnection?

    private nonisolated(unsafe) static var sharedHandler: WallpaperXPCHandler?
    private nonisolated(unsafe) static var retainedConnection: NSXPCConnection?

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let connPtr = Unmanaged.passUnretained(connection).toOpaque()
        syslog_trace("[Phosphene] shouldAcceptNewConnection ENTER conn=\(connPtr) PID=\(connection.processIdentifier)")
        Self.configureConnection(connection)
        let exportedPtr = connection.exportedObject.map { Unmanaged.passUnretained($0 as AnyObject).toOpaque() }
        syslog_trace("[Phosphene] shouldAcceptNewConnection EXIT conn=\(connPtr) exported=\(exportedPtr as Any)")
        return true
    }

    @objc static func preConfigureConnection(_ connection: NSXPCConnection) {
        let connPtr = Unmanaged.passUnretained(connection).toOpaque()
        let extProto: Protocol
        if let fwProto = objc_getProtocol("WallpaperExtensionKit.WallpaperExtensionXPCProtocol") {
            extProto = fwProto
            syslog_trace("[Phosphene] preConfig conn=\(connPtr) using framework proto")
        } else if let ours = objc_getProtocol("PhospheneWallpaperExtensionXPCProtocol") {
            extProto = ours
            syslog_trace("[Phosphene] preConfig conn=\(connPtr) using Phosphene proto")
        } else {
            syslog_trace("[Phosphene] preConfig conn=\(connPtr) NO PROTOCOL FOUND!")
            return
        }

        let exported = NSXPCInterface(with: extProto)
        let allTypes = buildAllowedClasses()
        let classes = allTypes as! Set<AnyHashable>

        for (sel, idx, isReply) in selectorWhitelist() {
            exported.setClasses(classes, for: sel, argumentIndex: idx, ofReply: isReply)
        }

        connection.exportedInterface = exported

        let handler = WallpaperXPCHandler()
        connection.exportedObject = handler
        sharedHandler = handler

        let basePtr = Unmanaged.passUnretained(connection as AnyObject).toOpaque()
        let exportInfo = basePtr.advanced(by: 56).load(as: UnsafeRawPointer?.self)
        syslog_trace("[Phosphene] preConfig DONE conn=\(connPtr) handler=\(Unmanaged.passUnretained(handler).toOpaque()) _exportInfo=\(exportInfo as Any)")
    }

    static func configureConnection(_ connection: NSXPCConnection) {
        let connPtr = Unmanaged.passUnretained(connection).toOpaque()
        let existingExported = connection.exportedObject.map { Unmanaged.passUnretained($0 as AnyObject).toOpaque() }
        syslog_trace("[Phosphene] configureConnection ENTER conn=\(connPtr) exported=\(existingExported as Any)")

        if connection.exportedObject == nil {
            preConfigureConnection(connection)
        }

        guard let handler = connection.exportedObject as? WallpaperXPCHandler else {
            syslog_trace("[Phosphene] FATAL: exportedObject is not WallpaperXPCHandler conn=\(connPtr)")
            return
        }

        let proxyProto: Protocol
        if let fwProxy = objc_getProtocol("WallpaperExtensionKit.WallpaperExtensionProxyXPCProtocol") {
            proxyProto = fwProxy
        } else if let ours = objc_getProtocol("PhospheneWallpaperExtensionProxyXPCProtocol") {
            proxyProto = ours
        } else {
            syslog_trace("[Phosphene] No proxy protocol found conn=\(connPtr)")
            return
        }
        connection.remoteObjectInterface = NSXPCInterface(with: proxyProto)

        connection.interruptionHandler = {
            syslog_trace("[Phosphene] XPC interrupted")
        }
        connection.invalidationHandler = { [weak handler] in
            syslog_trace("[Phosphene] XPC invalidated")
            handler?.agentProxy = nil
            let removed = WallpaperState.shared.removeAllContexts()
            if !removed.isEmpty {
                WallpaperPrefs.shared.setActive(false)
            }
            retainedConnection = nil
        }

        retainedConnection = connection

        syslog_trace("[Phosphene] configureConnection about to resume conn=\(connPtr)")
        connection.resume()

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            syslog_trace("[Phosphene] Remote proxy error: \(error)")
        }
        handler.agentProxy = proxy as? (any PhospheneWallpaperExtensionProxyXPCProtocol)

        let basePtr = Unmanaged.passUnretained(connection as AnyObject).toOpaque()
        let exportInfo = basePtr.advanced(by: 56).load(as: UnsafeRawPointer?.self)
        syslog_trace("[Phosphene] configureConnection DONE conn=\(connPtr) _exportInfo=\(exportInfo as Any) proxy=\(proxy)")
    }

    private static func buildAllowedClasses() -> NSMutableSet {
        let typeNames = [
            "WallpaperIDXPC", "WallpaperCreationRequestXPC", "WallpaperUpdateRequestXPC",
            "WallpaperRemoteContextXPC", "WallpaperSnapshotXPC", "WallpaperContentTypeSetXPC",
            "WallpaperChoiceIDXPC", "WallpaperChoiceIDsXPC", "WallpaperExtensionChoiceRequestXPC",
            "WallpaperChoiceRequestAdditionResultXPC", "WallpaperDebugRequestXPC",
            "WallpaperDebugResponseXPC", "WallpaperMigrationVersionXPC",
            "WallpaperSettingsViewModelsXPC", "AuditTokenXPC",
        ]
        let allTypes = NSMutableSet()
        for name in typeNames {
            if let cls = objc_getClass(name) { allTypes.add(cls) }
        }
        allTypes.add(NSString.self)
        allTypes.add(NSNumber.self)
        allTypes.add(NSData.self)
        allTypes.add(NSArray.self)
        allTypes.add(NSDictionary.self)
        allTypes.add(NSURL.self)
        allTypes.add(NSError.self)
        return allTypes
    }

    private static func selectorWhitelist() -> [(Selector, Int, Bool)] {
        [
            (#selector(WallpaperXPCHandler.acquire(withId:request:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.acquire(withId:request:reply:)), 1, false),
            (#selector(WallpaperXPCHandler.acquire(withId:request:reply:)), 0, true),
            (#selector(WallpaperXPCHandler.update(withId:request:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.update(withId:request:reply:)), 1, false),
            (#selector(WallpaperXPCHandler.invalidate(withId:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.snapshot(withId:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.snapshot(withId:reply:)), 0, true),
            (#selector(WallpaperXPCHandler.provideSettingsViewModels(withContentTypes:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.provideSettingsViewModels(withContentTypes:reply:)), 0, true),
            (#selector(WallpaperXPCHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 1, false),
            (#selector(WallpaperXPCHandler.addChoiceRequest(withChoiceRequest:onBehalfOfProcess:reply:)), 0, true),
            (#selector(WallpaperXPCHandler.removeChoiceRequest(withChoiceRequest:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.selectedChoicesDidChange(for:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.invokeContextMenuAction(withMenuItemID:groupItemID:reply:)), 1, false),
            (#selector(WallpaperXPCHandler.isChoiceDownloaded(with:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.download(withChoiceID:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.pauseDownload(for:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.cancelDownload(for:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.resumeDownload(for:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.removeDownload(for:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.migrateSelectedChoice(for:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.migrateSelectedChoice(for:reply:)), 0, true),
            (#selector(WallpaperXPCHandler.migrate(from:to:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.migrate(from:to:reply:)), 1, false),
            (#selector(WallpaperXPCHandler.skipShuffledContent(withId:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.canSkipShuffledContent(withId:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.handleDebugRequest(for:reply:)), 0, false),
            (#selector(WallpaperXPCHandler.handleDebugRequest(for:reply:)), 0, true),
            (#selector(WallpaperXPCHandler.handleNotification(withNamed:reply:)), 0, false),
        ]
    }
}
