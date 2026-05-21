import ExtensionFoundation
import Foundation
import WallpaperExtensionKit

struct PhospheneXPCConfiguration: AppExtensionConfiguration {
    init() {
        extensionLog("[conformer] PhospheneXPCConfiguration.init()")
    }

    nonisolated func accept(connection: NSXPCConnection) -> Bool {
        extensionLog("[conformer] accept(connection:) — PID \(connection.processIdentifier)")
        ExtensionXPCDelegate.configureConnection(connection)
        return true
    }
}

struct PhospheneWallpaper: WallpaperExtension {
    init() {
        extensionLog("[conformer] PhospheneWallpaper.init()")
    }

    var configuration: PhospheneXPCConfiguration {
        extensionLog("[conformer] PhospheneWallpaper.configuration accessed")
        return PhospheneXPCConfiguration()
    }

    func makeWallpaper(request: WallpaperCreationRequest, host: any WallpaperHostProxy) async throws -> any Wallpaper {
        fatalError("makeWallpaper not used")
    }
}
