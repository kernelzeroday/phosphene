import SwiftUI

@main
struct PhospheneApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var manager = PhospheneManager()

    var body: some Scene {
        Window("Phosphene", id: "library") {
            LibraryWindow(manager: manager)
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Phosphene") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .credits: Self.aboutCredits,
                    ])
                    NSApp.activate()
                }
            }
            SidebarCommands()
            InspectorCommands()
        }

        Settings {
            SettingsView(manager: manager)
        }
    }

    private static let aboutCredits: NSAttributedString = {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return NSAttributedString(string: "Video wallpapers for macOS", attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style,
        ])
    }()
}

// MARK: - URL Scheme Handling

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    nonisolated func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            for url in urls {
                guard url.scheme == "phosphene", url.host == "add-video" else { continue }
                PhospheneManager.shared?.openVideoChooser()
            }
        }
    }

}
