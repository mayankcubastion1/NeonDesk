import AppKit
import ScreenSaver

@objc(NeonDeskView)
final class NeonDeskView: ScreenSaverView {
    private var bootStart = Date().timeIntervalSinceReferenceDate

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 12.0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1.0 / 12.0
    }

    override func startAnimation() {
        super.startAnimation()
        bootStart = Date().timeIntervalSinceReferenceDate
    }

    override func animateOneFrame() {
        needsDisplay = true
    }

    override func draw(_ rect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let elapsed = Date().timeIntervalSinceReferenceDate - bootStart
        let cycle = elapsed.truncatingRemainder(dividingBy: 18)
        let boot = CGFloat(min(1, cycle / 4.0))
        let now = Date()
        let scene = RenderScene(
            now: now,
            mediaTime: elapsed,
            boot: cycle > 16 ? CGFloat((18 - cycle) / 2) : boot,
            intensity: 1,
            animate: true,
            themeID: ThemeID.resolved(at: now),
            reminder: DayPart.reminder(for: now, task: nil)
        )
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bounds.height)
        ctx.scaleBy(x: 1, y: -1)
        LEDRenderer.drawWallpaper(in: ctx, rect: bounds, scene: scene)
        ctx.restoreGState()
        let figureSize = StickFigure.canvasSize
        let figureRect = CGRect(
            x: bounds.midX - figureSize.width / 2,
            y: 36,
            width: figureSize.width,
            height: figureSize.height
        )
        let companion = CompanionScene(
            theme: scene.theme,
            now: now,
            mediaTime: elapsed,
            singing: false,
            pose: CompanionPose.forDate(now),
            reaction: .none,
            look: 0.18 * sin(elapsed * 0.7),
            lyricLine: "",
            lyricWord: "",
            lyricProgress: 0,
            cloudText: ""
        )
        StickFigure.draw(in: ctx, rect: figureRect, scene: companion)
    }

    override var hasConfigureSheet: Bool { false }
    override var configureSheet: NSWindow? { nil }
}
