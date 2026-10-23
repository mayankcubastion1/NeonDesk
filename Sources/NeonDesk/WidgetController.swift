import AppKit

enum WidgetKind {
    case clock
    case weather
    case spotify
    case transit
}

final class WidgetView: NSView {
    var kind: WidgetKind
    var onClick: (() -> Void)?

    init(kind: WidgetKind) {
        self.kind = kind
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        let model = DeskModel.shared
        let theme = model.theme
        switch kind {
        case .clock:
            LEDRenderer.drawClockPanel(in: ctx, rect: bounds, date: Date(), theme: theme)
        case .weather:
            LEDRenderer.drawWeatherPanel(in: ctx, rect: bounds, weather: model.weather, theme: theme)
        case .spotify:
            if let spotify = model.spotify {
                LEDRenderer.drawSpotifyPanel(in: ctx, rect: bounds, spotify: spotify, theme: theme)
            }
        case .transit:
            if let transit = model.transit {
                LEDRenderer.drawTransitPanel(in: ctx, rect: bounds, event: transit, theme: theme)
            }
        }
        ctx.restoreGState()
    }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }
}

final class WidgetController {
    private struct Cluster {
        var clock: NSWindow
        var weather: NSWindow
        var spotify: NSWindow
        var transit: NSWindow
        var screenID: CGDirectDisplayID
    }

    private var clusters: [Cluster] = []
    private var timer: Timer?

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(rebuild), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(modelChanged), name: .neonDeskDidChange, object: nil)
        rebuild()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.redraw()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    @objc private func modelChanged() {
        applyMode()
        restack()
        redraw()
    }

    @objc private func rebuild() {
        clusters.forEach {
            $0.clock.close()
            $0.weather.close()
            $0.spotify.close()
            $0.transit.close()
        }
        clusters = NSScreen.screens.map { makeCluster(on: $0) }
        applyMode()
    }

    private func makeCluster(on screen: NSScreen) -> Cluster {
        let clock = makeWindow(kind: .clock, size: NSSize(width: 220, height: 68), screen: screen)
        let weather = makeWindow(kind: .weather, size: NSSize(width: 200, height: 60), screen: screen)
        let spotify = makeWindow(kind: .spotify, size: NSSize(width: 320, height: 40), screen: screen)
        let transit = makeWindow(kind: .transit, size: NSSize(width: 160, height: 40), screen: screen)
        if let view = spotify.contentView as? WidgetView {
            view.onClick = { SpotifyService.playPause() }
        }
        var cluster = Cluster(clock: clock, weather: weather, spotify: spotify, transit: transit, screenID: screen.displayID)
        place(cluster: &cluster, on: screen)
        return cluster
    }

    private func restack() {
        for index in clusters.indices {
            if let screen = NSScreen.screens.first(where: { $0.displayID == clusters[index].screenID }) ?? NSScreen.screens.first {
                place(cluster: &clusters[index], on: screen)
            }
        }
    }

    private func place(cluster: inout Cluster, on screen: NSScreen) {
        let visible = screen.visibleFrame
        let left = visible.minX + 24
        place(cluster.clock, x: left, y: visible.maxY - 20 - 68)
        place(cluster.weather, x: left, y: visible.maxY - 20 - 68 - 12 - 60)
        place(cluster.spotify, x: left, y: visible.minY + 20)
        let spotifyShown = DeskModel.shared.spotify != nil && DeskModel.shared.mode != .off
        let transitX = spotifyShown ? left + 320 + 12 : left
        place(cluster.transit, x: transitX, y: visible.minY + 20)
    }

    private func makeWindow(kind: WidgetKind, size: NSSize, screen: NSScreen) -> NSWindow {
        let window = DesktopWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.canHide = false
        applyChrome(window)
        let view = WidgetView(kind: kind)
        view.frame = NSRect(origin: .zero, size: size)
        window.contentView = view
        window.orderFront(nil)
        return window
    }

    private func applyChrome(_ window: NSWindow) {
        let color = nsColor(DeskModel.shared.theme.panel)
        window.isOpaque = true
        window.backgroundColor = color
    }

    private func place(_ window: NSWindow, x: CGFloat, y: CGFloat) {
        var frame = window.frame
        frame.origin = CGPoint(x: x, y: y)
        window.setFrame(frame, display: true)
    }

    private func applyMode() {
        let model = DeskModel.shared
        let hidden = model.mode == .off
        let lifted = model.mode == .show
        for cluster in clusters {
            applyChrome(cluster.clock)
            applyChrome(cluster.weather)
            applyChrome(cluster.spotify)
            applyChrome(cluster.transit)
            cluster.clock.setIsVisible(!hidden)
            cluster.weather.setIsVisible(!hidden)
            cluster.spotify.setIsVisible(!hidden && model.spotify != nil)
            cluster.transit.setIsVisible(!hidden && model.transit != nil)
            let level = lifted
                ? NSWindow.Level.floating
                : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
            for window in [cluster.clock, cluster.weather, cluster.spotify, cluster.transit] {
                window.level = level
                window.ignoresMouseEvents = !(lifted && window === cluster.spotify)
                if lifted {
                    window.orderFront(nil)
                } else {
                    window.orderBack(nil)
                }
            }
        }
    }

    private func redraw() {
        for cluster in clusters {
            cluster.clock.contentView?.needsDisplay = true
            cluster.weather.contentView?.needsDisplay = true
            cluster.spotify.contentView?.needsDisplay = true
            cluster.transit.contentView?.needsDisplay = true
        }
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
