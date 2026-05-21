import SwiftUI

struct SettingsView: View {
    @Bindable var manager: PhospheneManager

    private var prefsService: WallpaperPrefsService { manager.prefsService }

    var body: some View {
        Form {
            Section("Playback") {
                Toggle("Only on Lock Screen", isOn: Bindable(prefsService).alwaysPauseDesktop)
                Toggle("Pause When Hidden", isOn: Binding(
                    get: { prefsService.pauseWhenOccluded },
                    set: { newValue in
                        prefsService.pauseWhenOccluded = newValue
                        if newValue {
                            manager.occlusionMonitor.startMonitoring()
                        } else {
                            manager.occlusionMonitor.stopMonitoring()
                        }
                    }
                ))
                .help("Pause playback when all screens are covered by windows")
            }

            Section("General") {
                Toggle("Resume on Launch", isOn: $manager.resumeLastWallpaper)
                Toggle("Launch at Login", isOn: $manager.launchAtLogin)
            }

            Section {
                Button("Open Wallpaper Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension")!)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize()
    }
}
