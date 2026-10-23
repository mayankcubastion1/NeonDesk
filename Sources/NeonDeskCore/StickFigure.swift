import AppKit
import CoreGraphics
import Foundation

public enum CompanionPose: String, Sendable {
    case stretch
    case type
    case sit
    case walk
    case read
    case lookUp
    case sleep

    public static func forHour(_ hour: Int) -> CompanionPose {
        switch hour {
        case 5..<8: return .stretch
        case 8..<13: return .type
        case 13..<17: return .sit
        case 17..<21: return .read
        case 21..<23: return .lookUp
        default: return .sleep
        }
    }

    public static func forDate(_ date: Date) -> CompanionPose {
        forHour(Calendar.current.component(.hour, from: date))
    }
}

public enum CompanionReaction: String, Sendable {
    case none
    case wave
    case jump
    case sitUp
    case carried
    case land
}

public struct CompanionScene: Sendable {
    public var theme: Theme
    public var now: Date
    public var mediaTime: TimeInterval
    public var singing: Bool
    public var pose: CompanionPose
    public var reaction: CompanionReaction
    public var look: CGFloat
    public var walking: Bool
    public var lyricLine: String
    public var lyricWord: String
    public var lyricProgress: CGFloat
    public var cloudText: String

    public init(
        theme: Theme,
        now: Date,
        mediaTime: TimeInterval,
        singing: Bool,
        pose: CompanionPose,
        reaction: CompanionReaction,
        look: CGFloat,
        walking: Bool = false,
        lyricLine: String,
        lyricWord: String,
        lyricProgress: CGFloat,
        cloudText: String
    ) {
        self.theme = theme
        self.now = now
        self.mediaTime = mediaTime
        self.singing = singing
        self.pose = pose
        self.reaction = reaction
        self.look = max(-1, min(1, look))
        self.walking = walking
        self.lyricLine = lyricLine
        self.lyricWord = lyricWord
        self.lyricProgress = max(0, min(1, lyricProgress))
        self.cloudText = cloudText
    }

    public var showsCloud: Bool {
        if reaction == .carried { return true }
        return !cloudText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || pose == .sleep && !singing && reaction != .sitUp && !walking
    }
}

public enum StickFigure {
    public static let canvasSize = CGSize(width: 340, height: 420)

    public static func draw(in ctx: CGContext, rect: CGRect, scene: CompanionScene) {
        ctx.saveGState()
        ctx.clip(to: rect)
        let time = scene.mediaTime
        let origin = CGPoint(x: rect.midX, y: rect.minY + 28)
        if scene.reaction != .carried {
            drawGroundProp(ctx, origin: origin, scene: scene)
        }
        drawBody(ctx, origin: origin, scene: scene, time: time)
        if scene.showsCloud {
            drawThought(ctx, origin: origin, scene: scene)
        }
        if scene.singing, !scene.lyricWord.isEmpty {
            drawDriftWord(ctx, origin: origin, scene: scene, time: time)
        }
        ctx.restoreGState()
    }

    public static func contains(_ point: CGPoint, in rect: CGRect, scene: CompanionScene) -> Bool {
        hitRects(in: rect, scene: scene).contains { $0.insetBy(dx: -10, dy: -10).contains(point) }
    }

    public static func hitRects(in rect: CGRect, scene: CompanionScene) -> [CGRect] {
        let mid = rect.midX
        var boxes = [CGRect]()
        if scene.reaction == .carried {
            boxes.append(CGRect(x: mid - 56, y: rect.minY + 40, width: 112, height: 220))
        } else if !scene.singing, !scene.walking, scene.pose == .sleep, scene.reaction != .sitUp {
            boxes.append(CGRect(x: mid - 100, y: rect.minY + 16, width: 200, height: 80))
        } else {
            boxes.append(CGRect(x: mid - 56, y: rect.minY + 10, width: 112, height: 200))
        }
        if scene.showsCloud {
            boxes.append(CGRect(x: mid - 120, y: rect.minY + 220, width: 240, height: 110))
        }
        return boxes
    }

    private static func drawBody(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval) {
        switch scene.reaction {
        case .carried:
            drawCarried(ctx, origin: origin, scene: scene, time: time)
        case .land:
            drawStanding(ctx, origin: origin.offset(x: 0, y: 10 + 6 * abs(sin(CGFloat(time) * 14))), scene: scene, time: time, wave: false, jump: 1)
        case .wave:
            drawStanding(ctx, origin: origin, scene: scene, time: time, wave: true, jump: 0)
        case .jump:
            drawStanding(ctx, origin: origin.offset(x: 0, y: 18 + 8 * abs(sin(CGFloat(time) * 10))), scene: scene, time: time, wave: false, jump: 1)
        case .sitUp:
            drawSit(ctx, origin: origin, scene: scene, time: time)
        case .none:
            if scene.walking {
                drawWalk(ctx, origin: origin, scene: scene, time: time, withMic: scene.singing)
            } else if scene.singing {
                drawSinger(ctx, origin: origin, scene: scene, time: time)
            } else {
                switch scene.pose {
                case .stretch: drawStretch(ctx, origin: origin, scene: scene, time: time)
                case .type: drawType(ctx, origin: origin, scene: scene, time: time)
                case .sit: drawSit(ctx, origin: origin, scene: scene, time: time)
                case .walk: drawWalk(ctx, origin: origin, scene: scene, time: time, withMic: false)
                case .read: drawRead(ctx, origin: origin, scene: scene, time: time)
                case .lookUp: drawLookUp(ctx, origin: origin, scene: scene, time: time)
                case .sleep: drawSleep(ctx, origin: origin, scene: scene, time: time)
                }
            }
        }
    }

    private static func drawSinger(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval) {
        let bounce = 3.2 * sin(CGFloat(time) * .pi * 4)
        let lean = 2.2 * sin(CGFloat(time) * 1.5)
        let hip = CGPoint(x: origin.x + lean, y: origin.y + 50 + bounce)
        let chest = CGPoint(x: hip.x, y: hip.y + 46)
        let head = CGPoint(x: chest.x + scene.look * 7, y: chest.y + 28)
        let leftFoot = CGPoint(x: origin.x - 12, y: origin.y)
        let rightFoot = CGPoint(x: origin.x + 12, y: origin.y)
        let leftHand = CGPoint(x: chest.x - 28, y: chest.y + 6 + 3 * sin(CGFloat(time) * 3))
        let micHand = CGPoint(x: chest.x + 22, y: chest.y + 20 + 2 * sin(CGFloat(time) * 8))

        stroke(ctx, scene.theme.body, 2.2)
        line(ctx, leftFoot, hip)
        line(ctx, rightFoot, hip)
        line(ctx, hip, chest)
        line(ctx, chest, leftHand)
        line(ctx, chest, micHand)
        drawHead(ctx, center: head, scene: scene, time: time, mouth: singingMouth(time))
        drawMic(ctx, hand: micHand, theme: scene.theme)
    }

    private static func drawStanding(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval, wave: Bool, jump: CGFloat) {
        let lean = 2 * sin(CGFloat(time) * 1.1)
        let hip = CGPoint(x: origin.x + lean, y: origin.y + 50)
        let chest = CGPoint(x: hip.x, y: hip.y + 46)
        let head = CGPoint(x: chest.x + scene.look * 8, y: chest.y + 28)
        let leftFoot = CGPoint(x: origin.x - 11, y: origin.y)
        let rightFoot = CGPoint(x: origin.x + 11, y: origin.y)
        let leftHand = CGPoint(x: chest.x - 24, y: chest.y - 4)
        let rightHand: CGPoint
        if wave {
            rightHand = CGPoint(x: chest.x + 26, y: chest.y + 34 + 8 * sin(CGFloat(time) * 9))
        } else {
            rightHand = CGPoint(x: chest.x + 22, y: chest.y - 2)
        }
        stroke(ctx, scene.theme.body, 2.2)
        line(ctx, leftFoot, hip)
        line(ctx, rightFoot, hip)
        line(ctx, hip, chest)
        line(ctx, chest, leftHand)
        line(ctx, chest, rightHand)
        drawHead(ctx, center: head, scene: scene, time: time, mouth: jump > 0 ? 0.5 : 0.12)
    }

    private static func drawStretch(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval) {
        let sway = 6 * sin(CGFloat(time) * 1.4)
        let hip = CGPoint(x: origin.x, y: origin.y + 50)
        let chest = CGPoint(x: hip.x, y: hip.y + 46)
        let head = CGPoint(x: chest.x + scene.look * 5, y: chest.y + 28)
        stroke(ctx, scene.theme.body, 2.2)
        line(ctx, CGPoint(x: origin.x - 12, y: origin.y), hip)
        line(ctx, CGPoint(x: origin.x + 12, y: origin.y), hip)
        line(ctx, hip, chest)
        line(ctx, chest, CGPoint(x: chest.x - 22 + sway, y: chest.y + 40))
        line(ctx, chest, CGPoint(x: chest.x + 22 + sway, y: chest.y + 42))
        drawHead(ctx, center: head, scene: scene, time: time, mouth: 0.2)
    }

    private static func drawType(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval) {
        let hip = CGPoint(x: origin.x, y: origin.y + 38)
        let chest = CGPoint(x: hip.x, y: hip.y + 40)
        let head = CGPoint(x: chest.x + 4 + scene.look * 6, y: chest.y + 26)
        let tap = 3 * abs(sin(CGFloat(time) * 8))
        stroke(ctx, scene.theme.body, 2.2)
        line(ctx, CGPoint(x: origin.x - 16, y: origin.y + 8), hip)
        line(ctx, CGPoint(x: origin.x + 18, y: origin.y), hip)
        line(ctx, hip, chest)
        line(ctx, chest, CGPoint(x: chest.x + 26, y: chest.y - 6 - tap))
        line(ctx, chest, CGPoint(x: chest.x + 34, y: chest.y - 4 + tap))
        drawHead(ctx, center: head, scene: scene, time: time, mouth: 0.1)
        stroke(ctx, scene.theme.accent, 1.6)
        ctx.stroke(CGRect(x: chest.x + 18, y: chest.y - 18, width: 28, height: 8))
        drawCup(ctx, at: CGPoint(x: origin.x - 28, y: origin.y + 4), theme: scene.theme, time: time)
    }

    private static func drawWalk(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval, withMic: Bool) {
        let face: CGFloat = scene.look >= 0 ? 1 : -1
        let step = sin(CGFloat(time) * 3.2)
        let hip = CGPoint(x: origin.x + step * 2 * face, y: origin.y + 50 + 2 * abs(step))
        let chest = CGPoint(x: hip.x, y: hip.y + 46)
        let head = CGPoint(x: chest.x + scene.look * 7, y: chest.y + 28)
        stroke(ctx, scene.theme.body, 2.2)
        line(ctx, CGPoint(x: origin.x - 14 * step * face, y: origin.y), hip)
        line(ctx, CGPoint(x: origin.x + 14 * step * face, y: origin.y), hip)
        line(ctx, hip, chest)
        let backHand = CGPoint(x: chest.x - 20 * step * face, y: chest.y + 4)
        let frontHand = CGPoint(x: chest.x + 20 * step * face, y: chest.y + 10)
        line(ctx, chest, backHand)
        line(ctx, chest, frontHand)
        drawHead(ctx, center: head, scene: scene, time: time, mouth: withMic ? singingMouth(time) : 0.15)
        if withMic {
            drawMic(ctx, hand: frontHand, theme: scene.theme)
        }
    }

    private static func drawCarried(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval) {
        let swing = 10 * sin(CGFloat(time) * 7)
        let hip = CGPoint(x: origin.x + swing * 0.15, y: origin.y + 72)
        let chest = CGPoint(x: hip.x, y: hip.y + 40)
        let head = CGPoint(x: chest.x + scene.look * 4, y: chest.y + 28)
        stroke(ctx, scene.theme.body, 2.2)
        line(ctx, CGPoint(x: hip.x - 8 + swing, y: origin.y + 18), hip)
        line(ctx, CGPoint(x: hip.x + 10 - swing, y: origin.y + 14), hip)
        line(ctx, hip, chest)
        line(ctx, chest, CGPoint(x: chest.x - 22, y: chest.y + 18))
        line(ctx, chest, CGPoint(x: chest.x + 20, y: chest.y + 16))
        drawHead(ctx, center: head, scene: scene, time: time, mouth: 0.7)
    }

    private static func drawRead(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval) {
        let nod = 2 * sin(CGFloat(time) * 0.8)
        let hip = CGPoint(x: origin.x, y: origin.y + 40)
        let chest = CGPoint(x: hip.x, y: hip.y + 42)
        let head = CGPoint(x: chest.x + 6 + scene.look * 4, y: chest.y + 22 + nod)
        stroke(ctx, scene.theme.body, 2.2)
        line(ctx, CGPoint(x: origin.x - 14, y: origin.y + 6), hip)
        line(ctx, CGPoint(x: origin.x + 16, y: origin.y), hip)
        line(ctx, hip, chest)
        let book = CGPoint(x: chest.x + 20, y: chest.y + 2)
        line(ctx, chest, book.offset(x: -8, y: -2))
        line(ctx, chest, book.offset(x: 8, y: -2))
        drawHead(ctx, center: head, scene: scene, time: time, mouth: 0.08)
        stroke(ctx, scene.theme.accent, 1.6)
        ctx.stroke(CGRect(x: book.x - 12, y: book.y - 10, width: 24, height: 16))
        line(ctx, CGPoint(x: book.x, y: book.y - 10), CGPoint(x: book.x, y: book.y + 6))
    }

    private static func drawLookUp(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval) {
        let hip = CGPoint(x: origin.x, y: origin.y + 50)
        let chest = CGPoint(x: hip.x, y: hip.y + 46)
        let head = CGPoint(x: chest.x + scene.look * 4, y: chest.y + 32)
        stroke(ctx, scene.theme.body, 2.2)
        line(ctx, CGPoint(x: origin.x - 11, y: origin.y), hip)
        line(ctx, CGPoint(x: origin.x + 12, y: origin.y), hip)
        line(ctx, hip, chest)
        line(ctx, chest, CGPoint(x: chest.x - 20, y: chest.y - 2))
        line(ctx, chest, CGPoint(x: chest.x + 16, y: chest.y + 22))
        drawHead(ctx, center: head, scene: scene, time: time, mouth: 0.18)
        stroke(ctx, scene.theme.accent, 1.4)
        let starY = origin.y + 168 + 4 * sin(CGFloat(time))
        drawStar(ctx, at: CGPoint(x: origin.x + 36, y: starY), r: 5)
    }

    private static func drawSleep(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval) {
        let y = origin.y + 18
        let head = CGPoint(x: origin.x - 52, y: y + 16)
        stroke(ctx, scene.theme.body, 2.2)
        line(ctx, CGPoint(x: origin.x - 34, y: y + 12), CGPoint(x: origin.x + 46, y: y + 10))
        line(ctx, CGPoint(x: origin.x + 8, y: y + 12), CGPoint(x: origin.x + 4, y: y + 28))
        line(ctx, CGPoint(x: origin.x + 46, y: y + 10), CGPoint(x: origin.x + 62, y: y + 8))
        drawHead(ctx, center: head, scene: scene, time: time, mouth: 0.05, eyesClosed: true)
        stroke(ctx, scene.theme.accent, 1.4)
        ctx.addEllipse(in: CGRect(x: head.x - 28, y: y + 2, width: 18, height: 10))
        ctx.strokePath()
    }

    private static func drawSit(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval) {
        let hip = CGPoint(x: origin.x, y: origin.y + 28)
        let chest = CGPoint(x: hip.x, y: hip.y + 38)
        let head = CGPoint(x: chest.x + scene.look * 6, y: chest.y + 26)
        stroke(ctx, scene.theme.body, 2.2)
        line(ctx, CGPoint(x: origin.x - 20, y: origin.y + 6), hip)
        line(ctx, CGPoint(x: origin.x + 26, y: origin.y + 6), hip)
        line(ctx, hip, chest)
        line(ctx, chest, CGPoint(x: chest.x - 18, y: chest.y - 8))
        line(ctx, chest, CGPoint(x: chest.x + 20, y: chest.y + 10))
        drawHead(ctx, center: head, scene: scene, time: time, mouth: 0.35)
    }

    private static func drawHead(
        _ ctx: CGContext,
        center: CGPoint,
        scene: CompanionScene,
        time: TimeInterval,
        mouth: CGFloat,
        eyesClosed: Bool = false
    ) {
        let r: CGFloat = 13
        stroke(ctx, scene.theme.body, 2)
        ctx.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ctx.strokePath()
        let blink = !eyesClosed && Int(time * 10) % 38 == 0
        let closed = eyesClosed || blink
        stroke(ctx, scene.theme.body, 1.4)
        let eyeY = center.y + 3
        let look = scene.look * 2.4
        if closed {
            line(ctx, CGPoint(x: center.x - 5 + look, y: eyeY), CGPoint(x: center.x - 2 + look, y: eyeY))
            line(ctx, CGPoint(x: center.x + 2 + look, y: eyeY), CGPoint(x: center.x + 5 + look, y: eyeY))
        } else {
            ctx.setFillColor(scene.theme.body.cgColor)
            ctx.fillEllipse(in: CGRect(x: center.x - 5 + look, y: eyeY, width: 2.2, height: 2.2))
            ctx.fillEllipse(in: CGRect(x: center.x + 3 + look, y: eyeY, width: 2.2, height: 2.2))
        }
        let mouthW = 3 + 5 * mouth
        let mouthH = 1 + 4 * mouth
        stroke(ctx, scene.theme.body, 1.4)
        ctx.addEllipse(in: CGRect(x: center.x - mouthW / 2, y: center.y - 7 - mouthH * 0.2, width: mouthW, height: mouthH))
        ctx.strokePath()
    }

    private static func drawMic(_ ctx: CGContext, hand: CGPoint, theme: Theme) {
        stroke(ctx, theme.accent, 2)
        let top = CGPoint(x: hand.x + 8, y: hand.y + 16)
        line(ctx, hand, top)
        ctx.setFillColor(theme.accent.cgColor)
        ctx.fillEllipse(in: CGRect(x: top.x - 6, y: top.y - 2, width: 12, height: 10))
        stroke(ctx, theme.body, 1.2)
        ctx.addEllipse(in: CGRect(x: top.x - 6, y: top.y - 2, width: 12, height: 10))
        ctx.strokePath()
    }

    private static func drawCup(_ ctx: CGContext, at point: CGPoint, theme: Theme, time: TimeInterval) {
        stroke(ctx, theme.accent, 1.5)
        ctx.stroke(CGRect(x: point.x, y: point.y, width: 10, height: 12))
        ctx.addArc(center: CGPoint(x: point.x + 10, y: point.y + 6), radius: 4, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
        ctx.strokePath()
        let steam = 3 * sin(CGFloat(time) * 2)
        line(ctx, CGPoint(x: point.x + 3, y: point.y + 13), CGPoint(x: point.x + 3 + steam, y: point.y + 22))
        line(ctx, CGPoint(x: point.x + 7, y: point.y + 13), CGPoint(x: point.x + 7 - steam, y: point.y + 21))
    }

    private static func drawStar(_ ctx: CGContext, at point: CGPoint, r: CGFloat) {
        var first = true
        for i in 0..<5 {
            let a = CGFloat(i) * .pi * 2 / 5 + .pi / 2
            let p = CGPoint(x: point.x + cos(a) * r, y: point.y + sin(a) * r)
            if first {
                ctx.move(to: p)
                first = false
            } else {
                ctx.addLine(to: p)
            }
        }
        ctx.closePath()
        ctx.strokePath()
    }

    private static func drawGroundProp(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene) {
        guard scene.singing || scene.reaction != .none else { return }
        stroke(ctx, scene.theme.accent, 1.4)
        switch scene.pose {
        case .stretch:
            line(ctx, CGPoint(x: origin.x - 36, y: origin.y - 4), CGPoint(x: origin.x + 36, y: origin.y - 4))
        case .type:
            drawCup(ctx, at: CGPoint(x: origin.x - 40, y: origin.y), theme: scene.theme, time: scene.mediaTime)
        case .sit:
            break
        case .walk:
            ctx.fillEllipse(in: CGRect(x: origin.x + 30, y: origin.y - 2, width: 4, height: 3))
        case .read:
            ctx.stroke(CGRect(x: origin.x + 28, y: origin.y - 2, width: 16, height: 11))
        case .lookUp:
            drawStar(ctx, at: CGPoint(x: origin.x + 34, y: origin.y + 8), r: 4)
        case .sleep:
            ctx.addEllipse(in: CGRect(x: origin.x + 24, y: origin.y - 2, width: 16, height: 8))
            ctx.strokePath()
        }
    }

    private static func drawThought(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene) {
        if scene.reaction == .carried {
            drawText(
                "!",
                in: ctx,
                rect: CGRect(x: origin.x + 18, y: origin.y + 210, width: 36, height: 28),
                font: .systemFont(ofSize: 22, weight: .bold),
                color: scene.theme.accent,
                alignment: .center
            )
            return
        }
        let sleeping = !scene.singing && !scene.walking && scene.pose == .sleep && scene.reaction != .sitUp
        let text = sleeping ? "z" : scene.cloudText
        guard !text.isEmpty else { return }
        let bubble = CGRect(x: origin.x - 118, y: origin.y + 196, width: 236, height: sleeping ? 54 : 96)
        let fill = scene.theme.panel
        ctx.setFillColor(fill.cgColor(alpha: 0.92))
        let path = CGPath(roundedRect: bubble, cornerWidth: 18, cornerHeight: 18, transform: nil)
        ctx.addPath(path)
        ctx.fillPath()
        stroke(ctx, scene.theme.accent, 1.4)
        ctx.addPath(path)
        ctx.strokePath()
        let dots = [
            CGPoint(x: origin.x - 8, y: origin.y + 186),
            CGPoint(x: origin.x - 18, y: origin.y + 172),
            CGPoint(x: origin.x - 12, y: origin.y + 160)
        ]
        for (i, dot) in dots.enumerated() {
            let r: CGFloat = i == 2 ? 3 : CGFloat(5 - i)
            ctx.setFillColor(scene.theme.accent.cgColor(alpha: 0.8))
            ctx.fillEllipse(in: CGRect(x: dot.x - r, y: dot.y - r, width: r * 2, height: r * 2))
        }
        drawText(
            sleeping ? "z  z  z" : text,
            in: ctx,
            rect: bubble.insetBy(dx: 14, dy: 12),
            font: .systemFont(ofSize: sleeping ? 18 : 13, weight: .medium),
            color: scene.theme.name,
            alignment: .center
        )
    }

    private static func drawDriftWord(_ ctx: CGContext, origin: CGPoint, scene: CompanionScene, time: TimeInterval) {
        let bounce = 3.2 * sin(CGFloat(time) * .pi * 4)
        let mic = CGPoint(x: origin.x + 30, y: origin.y + 118 + bounce)
        let dest = CGPoint(x: origin.x, y: origin.y + 210)
        let t = scene.lyricProgress
        let x = mic.x + (dest.x - mic.x) * t
        let y = mic.y + (dest.y - mic.y) * t + 8 * sin(t * .pi)
        let alpha = 1 - t * 0.85
        drawText(
            scene.lyricWord,
            in: ctx,
            rect: CGRect(x: x - 50, y: y, width: 100, height: 18),
            font: .systemFont(ofSize: 11, weight: .semibold),
            color: scene.theme.accent,
            alignment: .center,
            alpha: alpha
        )
    }

    private static func singingMouth(_ time: TimeInterval) -> CGFloat {
        0.35 + 0.65 * abs(sin(CGFloat(time) * .pi * 6))
    }

    private static func stroke(_ ctx: CGContext, _ color: RGB, _ width: CGFloat) {
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
    }

    private static func line(_ ctx: CGContext, _ a: CGPoint, _ b: CGPoint) {
        ctx.move(to: a)
        ctx.addLine(to: b)
        ctx.strokePath()
    }

    private static func drawText(
        _ text: String,
        in ctx: CGContext,
        rect: CGRect,
        font: NSFont,
        color: RGB,
        alignment: NSTextAlignment,
        alpha: CGFloat = 1
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(srgbRed: color.r, green: color.g, blue: color.b, alpha: alpha),
            .paragraphStyle: style
        ]
        let ns = text as NSString
        let box = ns.boundingRect(
            with: CGSize(width: rect.width, height: rect.height),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs
        )
        let drawRect = CGRect(
            x: rect.minX,
            y: rect.minY + max(0, (rect.height - box.height) / 2),
            width: rect.width,
            height: min(rect.height, ceil(box.height))
        )
        ns.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs)
    }
}

private extension CGPoint {
    func offset(x: CGFloat, y: CGFloat) -> CGPoint {
        CGPoint(x: self.x + x, y: self.y + y)
    }
}
