import AppKit

final class DesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class WallpaperView: NSView {
    override var isOpaque: Bool { true }
    override var wantsDefaultClipping: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        // AppKit views are flipped relative to our top-down LED math.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        LEDRenderer.drawWallpaper(in: ctx, rect: bounds, scene: DeskModel.shared.scene())
        ctx.restoreGState()
    }
}

final class WallpaperController {
    private var windows: [NSWindow] = []
    private var timer: Timer?
    private var lastFrame: TimeInterval = 0

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(rebuild), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(modelChanged), name: .neonDeskDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: NSWorkspace.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(wake), name: NSWorkspace.screensDidWakeNotification, object: NSWorkspace.shared)
        rebuild()
        startTimer()
    }

    @objc private func wake() {
        DeskModel.shared.replayBoot()
    }

    @objc private func modelChanged() {
        startTimer()
        redraw()
        let hidden = DeskModel.shared.mode == .off
        let color = nsColor(DeskModel.shared.theme.background)
        for window in windows {
            window.backgroundColor = color
            window.setIsVisible(!hidden)
        }
    }

    @objc private func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        guard DeskModel.shared.mode != .off else { return }
        for screen in NSScreen.screens {
            windows.append(makeWindow(for: screen))
        }
        redraw()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = DesktopWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.setFrame(screen.frame, display: true)
        window.isOpaque = true
        window.backgroundColor = nsColor(DeskModel.shared.theme.background)
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.sharingType = .readOnly
        window.canHide = false
        window.contentView = WallpaperView(frame: window.contentView?.bounds ?? screen.frame)
        window.orderBack(nil)
        return window
    }

    private func startTimer() {
        timer?.invalidate()
        let fps = DeskModel.shared.framesPerSecond
        guard fps > 0 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1 / fps, repeats: true) { [weak self] _ in
            self?.redraw()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func redraw() {
        for window in windows {
            window.contentView?.needsDisplay = true
        }
    }
}
