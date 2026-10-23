import AppKit

final class MenuBarController {
    private let item: NSStatusItem
    private var workItem: NSMenuItem!
    private var showItem: NSMenuItem!
    private var offItem: NSMenuItem!
    private var clockItem: NSMenuItem!
    private var companionItem: NSMenuItem!
    private var keepFrontItem: NSMenuItem!
    private var wanderItem: NSMenuItem!
    private var themeItems: [ThemeID: NSMenuItem] = [:]

    init() {
        item = NSStatusBar.system.statusItem(withLength: 26)
        item.button?.image = LEDRenderer.menuIcon(theme: DeskModel.shared.theme)
        item.button?.imagePosition = .imageOnly
        item.button?.toolTip = "NeonDesk"

        let menu = NSMenu()
        workItem = menu.addItem(withTitle: "Work", action: #selector(setWork), keyEquivalent: "")
        showItem = menu.addItem(withTitle: "Show Off (60s)", action: #selector(setShow), keyEquivalent: "n")
        showItem.keyEquivalentModifierMask = [.control, .option]
        offItem = menu.addItem(withTitle: "Off", action: #selector(setOff), keyEquivalent: "")
        for entry in [workItem, showItem, offItem] { entry?.target = self }

        menu.addItem(.separator())
        clockItem = menu.addItem(withTitle: "Follow the clock", action: #selector(followClock), keyEquivalent: "")
        clockItem.target = self
        for id in ThemeID.allCases {
            let entry = menu.addItem(withTitle: id.title, action: #selector(pinTheme(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = id.rawValue
            themeItems[id] = entry
        }

        menu.addItem(.separator())
        companionItem = menu.addItem(withTitle: "Companion", action: #selector(toggleCompanion), keyEquivalent: "")
        companionItem.target = self
        keepFrontItem = menu.addItem(withTitle: "Keep in front", action: #selector(toggleKeepFront), keyEquivalent: "")
        keepFrontItem.target = self
        wanderItem = menu.addItem(withTitle: "Wander", action: #selector(toggleWander), keyEquivalent: "")
        wanderItem.target = self

        menu.addItem(.separator())
        let saver = menu.addItem(withTitle: "Start Screensaver", action: #selector(startSaver), keyEquivalent: "")
        saver.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit NeonDesk", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        item.menu = menu

        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: .neonDeskDidChange, object: nil)
        refresh()
    }

    @objc private func refresh() {
        let model = DeskModel.shared
        workItem.state = model.mode == .work ? .on : .off
        showItem.state = model.mode == .show ? .on : .off
        offItem.state = model.mode == .off ? .on : .off
        clockItem.state = model.followClock ? .on : .off
        companionItem.state = model.companionEnabled ? .on : .off
        keepFrontItem.state = model.companionKeepFront ? .on : .off
        wanderItem.state = model.companionWander ? .on : .off
        for (id, entry) in themeItems {
            entry.state = (!model.followClock && model.themeID == id) ? .on : .off
        }
        item.button?.image = LEDRenderer.menuIcon(theme: model.theme)
    }

    @objc private func setWork() { DeskModel.shared.setMode(.work) }
    @objc private func setShow() { DeskModel.shared.setMode(.show) }
    @objc private func setOff() { DeskModel.shared.setMode(.off) }
    @objc private func followClock() { DeskModel.shared.followTheClock() }
    @objc private func toggleCompanion() { DeskModel.shared.setCompanionEnabled(!DeskModel.shared.companionEnabled) }
    @objc private func toggleKeepFront() { DeskModel.shared.setCompanionKeepFront(!DeskModel.shared.companionKeepFront) }
    @objc private func toggleWander() { DeskModel.shared.setCompanionWander(!DeskModel.shared.companionWander) }

    @objc private func pinTheme(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let id = ThemeID(rawValue: raw) else { return }
        DeskModel.shared.pinTheme(id)
    }

    @objc private func startSaver() {
        let engine = URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app")
        if FileManager.default.fileExists(atPath: engine.path) {
            NSWorkspace.shared.open(engine)
            return
        }
        ScreensaverWindow.present()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

final class ScreensaverWindow {
    static var windows: [NSWindow] = []
    private static var timer: Timer?

    static func present() {
        dismiss()
        for screen in NSScreen.screens {
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.setFrame(screen.frame, display: true)
            window.level = .screenSaver
            window.isOpaque = true
            window.backgroundColor = nsColor(DeskModel.shared.theme.background)
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = SaverCanvas(frame: screen.frame)
            window.makeKeyAndOrderFront(nil)
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { _ in
            windows.forEach { $0.contentView?.needsDisplay = true }
        }
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown]) { event in
            dismiss()
            return event
        }
    }

    static func dismiss() {
        timer?.invalidate()
        timer = nil
        windows.forEach { $0.close() }
        windows.removeAll()
    }
}

final class SaverCanvas: NSView {
    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        LEDRenderer.drawWallpaper(in: ctx, rect: bounds, scene: DeskModel.shared.scene())
        ctx.restoreGState()
        let now = Date()
        let figureSize = StickFigure.canvasSize
        let figureRect = CGRect(
            x: bounds.midX - figureSize.width / 2,
            y: 36,
            width: figureSize.width,
            height: figureSize.height
        )
        StickFigure.draw(
            in: ctx,
            rect: figureRect,
            scene: CompanionScene(
                theme: DeskModel.shared.theme,
                now: now,
                mediaTime: Date().timeIntervalSinceReferenceDate,
                singing: false,
                pose: CompanionPose.forDate(now),
                reaction: .none,
                look: 0,
                lyricLine: "",
                lyricWord: "",
                lyricProgress: 0,
                cloudText: ""
            )
        )
    }
}

func nsColor(_ rgb: RGB) -> NSColor {
    NSColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
}
