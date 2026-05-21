import Darwin.C
import ExtensionFoundation
import Foundation
import WallpaperExtensionKit

private final class Holder: @unchecked Sendable {
    static let shared = Holder()
    var singleton: NSObject?
    var listenerDelegate: ExtensionXPCDelegate?
    var machListener: NSXPCListener?
}

private func installInitSwizzle() {
    guard let cls = objc_getClass("_TtC19ExtensionFoundation19_EXRunningExtension") as? AnyClass else { return }
    let sel = NSSelectorFromString("init")
    guard let method = class_getInstanceMethod(cls, sel) else { return }
    let origIMP = method_getImplementation(method)
    typealias InitFunc = @convention(c) (AnyObject, Selector) -> AnyObject
    let origInit = unsafeBitCast(origIMP, to: InitFunc.self)

    let block: @convention(block) (AnyObject) -> AnyObject = { obj in
        let result = origInit(obj, sel)
        Holder.shared.singleton = result as? NSObject
        syslog_trace("[Phosphene] [init] Captured singleton: \(result)")

        if let nsObj = result as? NSObject {
            let basePtr = Unmanaged.passUnretained(nsObj).toOpaque()
            let existingIdentity = basePtr.advanced(by: 32).load(as: AnyObject?.self)
            if existingIdentity == nil {
                syslog_trace("[Phosphene] [init] Pre-seeding identity...")
                var err: NSError?
                if let identity = CreateExtensionIdentityFromBundle(&err) {
                    SetIvarAtOffset(nsObj, 32, identity)
                    syslog_trace("[Phosphene] [init] Identity set!")
                } else {
                    syslog_trace("[Phosphene] [init] Identity failed: \(err?.localizedDescription ?? "?")")
                }
            }
        }

        return result
    }
    method_setImplementation(method, imp_implementationWithBlock(block as Any))
}

private func dumpSingletonIvars() {
    guard let singleton = Holder.shared.singleton else { return }
    let cls: AnyClass = type(of: singleton)
    var ivarCount: UInt32 = 0
    guard let ivars = class_copyIvarList(cls, &ivarCount) else { return }
    defer { free(ivars) }
    let basePtr = Unmanaged.passUnretained(singleton).toOpaque()
    for i in 0..<Int(ivarCount) {
        let name = String(cString: ivar_getName(ivars[i])!)
        let offset = ivar_getOffset(ivars[i])
        let rawVal = basePtr.advanced(by: offset).load(as: UnsafeRawPointer?.self)
        syslog_trace("[Phosphene] [ivar] \(name) @\(offset): \(rawVal.map { "\($0)" } ?? "nil")")
    }
}

private func patchShouldAccept() {
    guard let runningCls = objc_getClass("_TtC19ExtensionFoundation19_EXRunningExtension") as? AnyClass else { return }
    let classPtr = unsafeBitCast(runningCls, to: UnsafeMutablePointer<UnsafeRawPointer?>.self)

    var shouldAcceptSlot = -1
    for i in 0..<48 {
        guard let slot = classPtr.advanced(by: i).pointee else { continue }
        var info = Dl_info()
        if dladdr(slot, &info) != 0, let sname = info.dli_sname {
            if String(cString: sname).contains("shouldAccept") {
                shouldAcceptSlot = i
                break
            }
        }
    }
    guard shouldAcceptSlot >= 0 else {
        syslog_trace("[Phosphene] [vtable] shouldAccept not found")
        return
    }

    typealias ShouldAcceptFunc = @convention(c) (AnyObject, AnyObject) -> Bool
    let replacement: ShouldAcceptFunc = { arg0, arg1 in
        let connection: NSXPCConnection
        if let c = arg0 as? NSXPCConnection {
            connection = c
        } else if let c = arg1 as? NSXPCConnection {
            connection = c
        } else {
            syslog_trace("[Phosphene] [vtable] shouldAccept: no NSXPCConnection")
            return true
        }
        syslog_trace("[Phosphene] [vtable] shouldAccept: PID \(connection.processIdentifier)")
        ExtensionXPCDelegate.configureConnection(connection)
        return true
    }
    let replacementPtr = unsafeBitCast(replacement, to: UnsafeRawPointer.self)

    let pageSize = Int(getpagesize())
    let slotAddr = UnsafeMutableRawPointer(classPtr.advanced(by: shouldAcceptSlot))
    let pageStart = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: slotAddr) & ~UInt(pageSize - 1))!
    let kr = vm_protect(mach_task_self_, vm_address_t(UInt(bitPattern: pageStart)), vm_size_t(pageSize * 2), 0, VM_PROT_READ | VM_PROT_WRITE)
    if kr == KERN_SUCCESS {
        classPtr.advanced(by: shouldAcceptSlot).pointee = replacementPtr
        syslog_trace("[Phosphene] [vtable] Patched shouldAccept at slot \(shouldAcceptSlot)")
    }
}

@MainActor
func run() {
    if ext_main_already_called() != 0 {
        syslog_trace("[Phosphene] Reentered from _start — returning")
        extensionLog("=== Reentered from _start — returning ===")
        return
    }

    syslog_trace("[Phosphene] === main() PID \(ProcessInfo.processInfo.processIdentifier) ===")
    extensionLog("=== main() PID \(ProcessInfo.processInfo.processIdentifier) ===")
    _ = PhospheneExtension.shared
    installInitSwizzle()
    patchShouldAccept()

    InstallXPCConnectionSwizzle { connection in
        ExtensionXPCDelegate.configureConnection(connection)
    }

    set_ext_main_called()
    install_sigtrap_skip_handler()

    // Phase 1: PhospheneWallpaper.main() sets _appExtension @72 on the
    // singleton via the AppExtension.main() → EXExtensionMain path.
    // _start() runs internally but fails the type check; AppExtension
    // handles reentry itself and returns.  internalListener stays nil.
    syslog_trace("[Phosphene] === Phase 1: PhospheneWallpaper.main() ===")
    extensionLog("=== Phase 1: PhospheneWallpaper.main() ===")
    do {
        try PhospheneWallpaper.main()
    } catch {
        syslog_trace("[Phosphene] Phase 1 threw: \(error)")
    }
    syslog_trace("[Phosphene] Phase 1 done")
    dumpSingletonIvars()

    // Phase 2: Call EXExtensionMain directly.  This triggers _start()
    // again, which reenters our binary's main().  We detect reentry
    // (ext_main_already_called) and return.  _start() continues with
    // _appExtension already set.  The SIGTRAP handler skips past the
    // type-check assertion so _start() can create internalListener @16.
    // If _start() succeeds it enters its own run loop (never returns).
    syslog_trace("[Phosphene] === Phase 2: EXExtensionMain ===")
    extensionLog("=== Phase 2: EXExtensionMain ===")
    let result = EXExtensionMain(CommandLine.argc, CommandLine.unsafeArgv)
    syslog_trace("[Phosphene] Phase 2 returned: \(result)")
    extensionLog("=== Phase 2 returned: \(result) ===")

    dumpSingletonIvars()

    // Fallback: if Phase 2 returned (i.e. _start() didn't enter a run
    // loop), set up our own Mach service listener.
    let delegate = ExtensionXPCDelegate()
    Holder.shared.listenerDelegate = delegate
    let listener = NSXPCListener(machServiceName: "dev.phosphene.extension")
    listener.delegate = delegate
    InstallShouldAcceptSwizzle(delegate)
    listener.resume()
    Holder.shared.machListener = listener
    syslog_trace("[Phosphene] Mach listener ready")

    syslog_trace("[Phosphene] === Entering dispatchMain ===")
    extensionLog("=== Entering dispatchMain ===")
    dispatchMain()
}

run()
