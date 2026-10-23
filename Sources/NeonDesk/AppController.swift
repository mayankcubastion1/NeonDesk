import AppKit
import ServiceManagement

final class AppController: NSObject, NSApplicationDelegate {
    private var wallpaper: WallpaperController?
    private var widgets: WidgetController?
    private var companion: CompanionController?
    private var menuBar: MenuBarController?
    private let stateDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("NeonDesk/state", isDirectory: true)

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--write-stills") {
            DeskModel.shared.applyStoredTheme()
            DeskModel.shared.loadReminder()
            do {
                _ = try WallpaperService.writeStills(scene: DeskModel.shared.stillScene())
                WallpaperService.applyStills()
            } catch {
                fputs("NeonDesk stills failed: \(error)\n", stderr)
                exit(1)
            }
            exit(0)
        }
        if CommandLine.arguments.contains("--uninstall-login-item") {
            try? SMAppService.mainApp.unregister()
            exit(0)
        }
        if CommandLine.arguments.contains("--register-login-item") {
            try? SMAppService.mainApp.register()
            exit(0)
        }

        try? FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        WallpaperService.backupCurrent(to: stateDir)
        DeskModel.shared.start()
        wallpaper = WallpaperController()
        widgets = WidgetController()
        companion = CompanionController()
        menuBar = MenuBarController()
        HotkeyMonitor.shared.onToggleShow = { DeskModel.shared.toggleShow() }
        HotkeyMonitor.shared.register()

        do {
            try SMAppService.mainApp.register()
        } catch {
            NSLog("NeonDesk: login item register skipped: %@", error.localizedDescription)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
