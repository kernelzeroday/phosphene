// Helper to swizzle ExtensionFoundation's type check so our com.apple.wallpaper
// extension can use the normal AppExtension.main() lifecycle.

import AppKit
import Foundation

enum SwizzleHelpers {
    private nonisolated(unsafe) static var origShouldAcceptIMP: IMP?

    @MainActor
    static func swizzleShouldAccept(on delegate: NSObject) {
        let cls: AnyClass = type(of: delegate)
        let sel = NSSelectorFromString("listener:shouldAcceptNewConnection:")
        guard let method = class_getInstanceMethod(cls, sel) else {
            extensionLog("  [Swizzle] listener:shouldAcceptNewConnection: not found on \(NSStringFromClass(cls))")
            return
        }

        origShouldAcceptIMP = method_getImplementation(method)
        typealias ShouldAcceptFunc = @convention(c) (AnyObject, Selector, AnyObject, NSXPCConnection) -> Bool
        let origFunc = unsafeBitCast(origShouldAcceptIMP!, to: ShouldAcceptFunc.self)

        let block: @convention(block) (AnyObject, AnyObject, NSXPCConnection) -> Bool = { selfObj, listener, connection in
            extensionLog("[Swizzle] shouldAccept called — PID \(connection.processIdentifier)")

            // Let ExtensionFoundation handle the connection first
            let result = origFunc(selfObj, sel, listener, connection)
            extensionLog("[Swizzle] original returned \(result)")

            if result {
                // ExtensionFoundation accepted — now inject our handler
                extensionLog("[Swizzle] injecting our exported interface + handler")
                ExtensionXPCDelegate.configureConnection(connection)
            }

            return result
        }

        let newIMP = imp_implementationWithBlock(block as Any)
        method_setImplementation(method, newIMP)
        extensionLog("  [Swizzle] Patched \(NSStringFromClass(cls)).listener:shouldAcceptNewConnection:")
    }
}
