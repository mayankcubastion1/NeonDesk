import AppKit

final class CompanionView: NSView {
    var look: CGFloat = 0
    var onPickup: (() -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onDrop: ((Bool) -> Void)?

    private var grabOffset = CGPoint.zero
    private var dragged = false

    override var isOpaque: Bool { false }
    override var wantsDefaultClipping: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.setBlendMode(.copy)
        ctx.setFillColor(NSColor.clear.cgColor)
        ctx.fill(bounds)
        ctx.setBlendMode(.normal)
        StickFigure.draw(in: ctx, rect: bounds, scene: CompanionController.shared?.scene(look: look) ?? .idle)
        ctx.restoreGState()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let scene = CompanionController.shared?.scene(look: look) ?? .idle
        return StickFigure.contains(point, in: bounds, scene: scene) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        grabOffset = event.locationInWindow
        dragged = false
        onPickup?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let screen = window.convertPoint(toScreen: event.locationInWindow)
        let origin = CGPoint(x: screen.x - grabOffset.x, y: screen.y - grabOffset.y)
        if hypot(origin.x - window.frame.minX, origin.y - window.frame.minY) > 3 {
            dragged = true
        }
        if dragged {
            onDrag?(origin)
        }
    }

    override func mouseUp(with event: NSEvent) {
        onDrop?(dragged)
        dragged = false
    }
}

final class CompanionController {
    static private(set) var shared: CompanionController?

    private var window: NSWindow?
    private var timer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var dragging = false
    private var walking = false
    private var facing: CGFloat = 1
    private var restUntil: TimeInterval = 0
    private var walkFrom = CGPoint.zero
    private var walkTo = CGPoint.zero
    private var walkBegan: TimeInterval = 0
    private var lastTick: TimeInterval = 0

    init() {
        CompanionController.shared = self
        NotificationCenter.default.addObserver(self, selector: #selector(modelChanged), name: .neonDeskDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        rebuild()
        restUntil = Date().timeIntervalSinceReferenceDate + 8
        startTimer()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.trackMouse()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.trackMouse()
            return event
        }
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    func scene(look: CGFloat) -> CompanionScene {
        let model = DeskModel.shared
        let now = Date()
        let host = now.timeIntervalSinceReferenceDate
        let singing = model.spotify?.playing == true
        let moment = model.lyricMoment(at: host)
        let fallback = model.spotify.map { "\($0.title)  \($0.artist)" } ?? ""
        let reaction: CompanionReaction
        if dragging {
            reaction = .carried
        } else {
            reaction = model.currentReaction()
        }
        let cloud: String
        if dragging {
            cloud = "!"
        } else if singing {
            let line = moment?.line.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            cloud = line.isEmpty ? fallback : line
        } else if let poke = model.companionPokeText, reaction != .none {
            cloud = poke
        } else {
            cloud = ""
        }
        let hoverOrFace = dragging || walking ? facing : look
        return CompanionScene(
            theme: model.theme,
            now: now,
            mediaTime: host,
            singing: singing,
            pose: CompanionPose.forDate(now),
            reaction: reaction,
            look: hoverOrFace,
            walking: walking && !dragging,
            lyricLine: moment?.line ?? "",
            lyricWord: moment?.word ?? "",
            lyricProgress: moment?.progress ?? 0,
            cloudText: cloud
        )
    }

    @objc private func modelChanged() {
        applyMode()
        startTimer()
        window?.contentView?.needsDisplay = true
    }

    @objc private func screensChanged() {
        rebuild()
    }

    private func rebuild() {
        window?.close()
        window = nil
        guard DeskModel.shared.companionVisible else { return }
        let size = StickFigure.canvasSize
        let win = DesktopWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        win.isReleasedWhenClosed = false
        win.animationBehavior = .none
        win.canHide = false
        let view = CompanionView(frame: NSRect(origin: .zero, size: size))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.onPickup = { [weak self] in
            self?.pickup()
        }
        view.onDrag = { [weak self] origin in
            self?.drag(to: origin)
        }
        view.onDrop = { [weak self] didDrag in
            self?.drop(didDrag: didDrag)
        }
        win.contentView = view
        window = win
        placeDefault()
        applyMode()
        win.orderFront(nil)
    }

    private func placeDefault() {
        guard let window else { return }
        let size = window.frame.size
        if let x = DeskModel.shared.companionX, let y = DeskModel.shared.companionY {
            window.setFrame(clamp(NSRect(x: x, y: y, width: size.width, height: size.height)), display: true)
            return
        }
        let screen = screenForSavedX() ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visible = screen.visibleFrame
        let x = DeskModel.shared.companionX ?? (visible.midX - size.width / 2)
        let y = visible.minY + 8
        window.setFrame(clamp(NSRect(x: x, y: y, width: size.width, height: size.height)), display: true)
    }

    private func screenForSavedX() -> NSScreen? {
        guard let x = DeskModel.shared.companionX else { return NSScreen.main }
        return NSScreen.screens.first { $0.frame.minX <= x && x < $0.frame.maxX } ?? NSScreen.main
    }

    private func pickup() {
        dragging = true
        walking = false
        DeskModel.shared.setCompanionReaction(.carried, seconds: 60)
    }

    private func drag(to origin: CGPoint) {
        dragging = true
        walking = false
        guard let window else { return }
        var frame = window.frame
        frame.origin = origin
        frame = clamp(frame)
        window.setFrame(frame, display: true)
        facing = origin.x >= window.frame.minX ? facing : (origin.x < DeskModel.shared.companionX ?? origin.x ? -1 : 1)
        if let previous = DeskModel.shared.companionX {
            if origin.x > previous + 2 { facing = 1 }
            if origin.x < previous - 2 { facing = -1 }
        }
        DeskModel.shared.setCompanionOrigin(x: frame.origin.x, y: frame.origin.y, persist: false)
    }

    private func drop(didDrag: Bool) {
        dragging = false
        if didDrag {
            DeskModel.shared.setCompanionReaction(.land, seconds: 0.8)
            restUntil = Date().timeIntervalSinceReferenceDate + 8
            if let window {
                DeskModel.shared.setCompanionOrigin(x: window.frame.minX, y: window.frame.minY)
            }
        } else {
            DeskModel.shared.clearCompanionReaction()
            DeskModel.shared.pokeCompanion()
        }
    }

    private func applyMode() {
        let model = DeskModel.shared
        guard let window else {
            if model.companionVisible { rebuild() }
            return
        }
        if !model.companionVisible {
            window.setIsVisible(false)
            walking = false
            return
        }
        window.setIsVisible(true)
        let lifted = model.mode == .show || model.companionKeepFront
        window.level = lifted
            ? NSWindow.Level.floating
            : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        if lifted {
            window.orderFront(nil)
        } else {
            window.orderBack(nil)
        }
        if !model.companionWander {
            walking = false
        }
        trackMouse()
    }

    private func startTimer() {
        timer?.invalidate()
        let fps = DeskModel.shared.companionFramesPerSecond
        guard fps > 0 else { return }
        lastTick = Date().timeIntervalSinceReferenceDate
        timer = Timer.scheduledTimer(withTimeInterval: 1 / fps, repeats: true) { [weak self] _ in
            self?.tickMotion()
            self?.window?.contentView?.needsDisplay = true
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func tickMotion() {
        let now = Date().timeIntervalSinceReferenceDate
        lastTick = now
        guard !dragging, DeskModel.shared.companionVisible else { return }
        if walking {
            stepWalk(now: now)
            return
        }
        guard DeskModel.shared.companionWander, now >= restUntil else { return }
        beginWalk()
    }

    private func beginWalk() {
        guard let window, let dest = randomPerch(avoiding: window.frame.origin) else {
            restUntil = Date().timeIntervalSinceReferenceDate + 20
            return
        }
        walkFrom = window.frame.origin
        walkTo = dest
        walkBegan = Date().timeIntervalSinceReferenceDate
        walking = true
        facing = dest.x >= walkFrom.x ? 1 : -1
    }

    private func stepWalk(now: TimeInterval) {
        guard let window else {
            walking = false
            return
        }
        let dx = walkTo.x - walkFrom.x
        let dy = walkTo.y - walkFrom.y
        let distance = max(1, hypot(dx, dy))
        let speed: CGFloat = 180
        let t = min(1, CGFloat(now - walkBegan) * speed / distance)
        let origin = CGPoint(x: walkFrom.x + dx * t, y: walkFrom.y + dy * t)
        var frame = window.frame
        frame.origin = origin
        window.setFrame(frame, display: false)
        if t >= 1 {
            walking = false
            restUntil = now + TimeInterval.random(in: 20...45)
            DeskModel.shared.setCompanionOrigin(x: walkTo.x, y: walkTo.y)
        }
    }

    private func randomPerch(avoiding current: CGPoint) -> CGPoint? {
        let size = StickFigure.canvasSize
        var spots: [CGPoint] = []
        for screen in NSScreen.screens {
            let visible = screen.visibleFrame
            let minX = visible.minX + 8
            let maxX = visible.maxX - size.width - 8
            let minY = visible.minY + 4
            let maxY = visible.maxY - size.height - 4
            guard maxX > minX, maxY > minY else { continue }
            for _ in 0..<6 {
                spots.append(CGPoint(
                    x: CGFloat.random(in: minX...maxX),
                    y: CGFloat.random(in: minY...maxY)
                ))
            }
        }
        spots.removeAll { hypot($0.x - current.x, $0.y - current.y) < 160 }
        return spots.randomElement()
    }

    private func clamp(_ frame: NSRect) -> NSRect {
        var next = frame
        let mid = CGPoint(x: frame.midX, y: frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(mid) }
            ?? NSScreen.screens.min(by: { abs($0.frame.midX - mid.x) < abs($1.frame.midX - mid.x) })
        guard let visible = screen?.visibleFrame else { return frame }
        next.origin.x = min(max(frame.origin.x, visible.minX - 40), visible.maxX - frame.width + 40)
        next.origin.y = min(max(frame.origin.y, visible.minY - 20), visible.maxY - frame.height + 20)
        return next
    }

    private func trackMouse() {
        guard let window, let view = window.contentView as? CompanionView, window.isVisible else { return }
        let screenPoint = NSEvent.mouseLocation
        let local = window.convertPoint(fromScreen: screenPoint)
        let scene = self.scene(look: view.look)
        let over = StickFigure.contains(local, in: view.bounds, scene: scene)
        window.ignoresMouseEvents = !over && !dragging
        if NSEvent.pressedMouseButtons == 0, dragging {
            drop(didDrag: true)
        }
        if dragging || walking {
            return
        }
        if over {
            let headX = window.frame.midX
            view.look = max(-1, min(1, (screenPoint.x - headX) / 70))
        } else {
            view.look *= 0.82
            if abs(view.look) < 0.04 { view.look = 0 }
        }
    }
}

private extension CompanionScene {
    static var idle: CompanionScene {
        let now = Date()
        return CompanionScene(
            theme: Theme.palette(.quietNight),
            now: now,
            mediaTime: 0,
            singing: false,
            pose: CompanionPose.forDate(now),
            reaction: .none,
            look: 0,
            walking: false,
            lyricLine: "",
            lyricWord: "",
            lyricProgress: 0,
            cloudText: ""
        )
    }
}
