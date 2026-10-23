import AppKit
import CoreGraphics
import Foundation

public enum LEDRenderer {
    public static func drawWallpaper(in ctx: CGContext, rect: CGRect, scene: RenderScene) {
        let theme = scene.theme
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.setFillColor(theme.background.cgColor)
        ctx.fill(rect)

        if theme.showsGrid {
            drawGrid(ctx, rect: rect, color: theme.grid, step: 18)
        }
        if theme.id == .neon {
            drawVignette(ctx, rect: rect, background: theme.background)
        }

        let fadeIn = fade(scene.boot, start: 0.08, end: 0.55)
        if theme.usesLED {
            drawLEDName(ctx, rect: rect, scene: scene, alpha: fadeIn)
        } else {
            drawTypeName(ctx, rect: rect, scene: scene, alpha: fadeIn)
        }

        let lineAlpha = fade(scene.boot, start: 0.45, end: 0.85)
        if lineAlpha > 0.04 {
            ctx.saveGState()
            ctx.setAlpha(lineAlpha)
            drawReminder(ctx, rect: rect, scene: scene)
            ctx.restoreGState()
        }

        if theme.showsEqualizer {
            let eqAlpha = fade(scene.boot, start: 0.5, end: 0.85)
            if eqAlpha > 0.04 {
                ctx.saveGState()
                ctx.setAlpha(eqAlpha)
                drawEqualizer(ctx: ctx, rect: rect, time: scene.mediaTime, animate: scene.animate, intensity: scene.intensity)
                ctx.restoreGState()
            }
        }
        ctx.restoreGState()
    }

    public static func drawClockPanel(in ctx: CGContext, rect: CGRect, date: Date, theme: Theme) {
        fillPanel(ctx, rect: rect, color: theme.panel)
        let pad: CGFloat = 16
        let time = clockTime(date)
        let day = clockDay(date)
        drawSystemText(
            time,
            in: ctx,
            rect: CGRect(x: rect.minX + pad, y: rect.minY + 12, width: rect.width - pad * 2 - 72, height: 28),
            font: .monospacedDigitSystemFont(ofSize: 26, weight: .medium),
            color: theme.name,
            alignment: .left
        )
        drawSystemText(
            "online",
            in: ctx,
            rect: CGRect(x: rect.maxX - pad - 68, y: rect.minY + 18, width: 68, height: 18),
            font: .systemFont(ofSize: 11, weight: .medium),
            color: theme.accent,
            alignment: .right
        )
        drawSystemText(
            day,
            in: ctx,
            rect: CGRect(x: rect.minX + pad, y: rect.minY + 42, width: rect.width - pad * 2, height: 18),
            font: .systemFont(ofSize: 12, weight: .regular),
            color: theme.body,
            alignment: .left
        )
    }

    public static func drawWeatherPanel(in ctx: CGContext, rect: CGRect, weather: WeatherSnapshot?, theme: Theme) {
        fillPanel(ctx, rect: rect, color: theme.panel)
        let pad: CGFloat = 16
        drawSystemText(
            "Gurugram",
            in: ctx,
            rect: CGRect(x: rect.minX + pad, y: rect.minY + 10, width: rect.width - pad * 2, height: 18),
            font: .systemFont(ofSize: 12, weight: .medium),
            color: theme.body,
            alignment: .left
        )
        drawSystemText(
            weather?.display ?? "—",
            in: ctx,
            rect: CGRect(x: rect.minX + pad, y: rect.minY + 30, width: rect.width - pad * 2, height: 22),
            font: .systemFont(ofSize: 18, weight: .medium),
            color: theme.name,
            alignment: .left
        )
    }

    public static func drawSpotifyPanel(in ctx: CGContext, rect: CGRect, spotify: SpotifySnapshot, theme: Theme) {
        fillPanel(ctx, rect: rect, color: theme.panel)
        let pad: CGFloat = 16
        let mark = spotify.playing ? "▶" : "❚❚"
        drawSystemText(
            "\(mark)  \(spotify.line)",
            in: ctx,
            rect: CGRect(x: rect.minX + pad, y: rect.minY + 10, width: rect.width - pad * 2, height: 20),
            font: .systemFont(ofSize: 13, weight: .medium),
            color: theme.name,
            alignment: .left
        )
    }

    public static func drawTransitPanel(in ctx: CGContext, rect: CGRect, event: TransitEvent, theme: Theme) {
        fillPanel(ctx, rect: rect, color: theme.panel)
        let pad: CGFloat = 16
        drawSystemText(
            event.label,
            in: ctx,
            rect: CGRect(x: rect.minX + pad, y: rect.minY + 10, width: rect.width - pad * 2, height: 20),
            font: .systemFont(ofSize: 12, weight: .medium),
            color: theme.accent,
            alignment: .left
        )
    }

    public static func image(size: CGSize, scale: CGFloat, scene: RenderScene) -> NSImage {
        let pixels = NSSize(width: size.width * scale, height: size.height * scale)
        let image = NSImage(size: size)
        image.addRepresentation(makeRep(pixelSize: pixels, scale: scale) { ctx in
            ctx.translateBy(x: 0, y: pixels.height)
            ctx.scaleBy(x: scale, y: -scale)
            drawWallpaper(in: ctx, rect: CGRect(origin: .zero, size: size), scene: scene)
        })
        return image
    }

    public static func writeStill(size: CGSize, to url: URL, scene: RenderScene = .still()) throws {
        let image = self.image(size: size, scale: 1, scene: scene)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else {
            throw NSError(domain: "NeonDesk", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not encode still"])
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try png.write(to: url)
    }

    public static func menuIcon(theme: Theme = Theme.palette(.quietNight)) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18))
        image.addRepresentation(makeRep(pixelSize: NSSize(width: 36, height: 36), scale: 2) { ctx in
            ctx.setFillColor(theme.accent.cgColor)
            ctx.fillEllipse(in: CGRect(x: 8, y: 8, width: 20, height: 20))
        })
        image.isTemplate = false
        return image
    }

    private static func drawLEDName(_ ctx: CGContext, rect: CGRect, scene: RenderScene, alpha: CGFloat) {
        guard alpha > 0.04 else { return }
        let scale = min(rect.width / 2560, rect.height / 1664)
        let pulse: CGFloat = scene.animate ? 0.8 + 0.12 * sin(scene.mediaTime * .pi / 4) : 0.86
        let scanX: CGFloat? = scene.animate
            ? rect.minX - 80 + (rect.width + 160) * CGFloat((scene.mediaTime.truncatingRemainder(dividingBy: 10)) / 10)
            : nil
        let namePitch = max(11, 17 * scale * (rect.width < 2000 ? 0.92 : 1))
        let nameGap = namePitch * 0.86
        let nameRadius = max(2.1, namePitch * 0.34)
        let space = namePitch * 2.2
        let first = reveal(scene.firstName, start: 0.02, end: 0.38, boot: scene.boot)
        let last = reveal(scene.lastName, start: 0.32, end: 0.68, boot: scene.boot)
        let firstW = LEDFont.textWidth(scene.firstName, pitch: namePitch, gap: nameGap)
        let titleW = firstW + space + LEDFont.textWidth(scene.lastName, pitch: namePitch, gap: nameGap)
        let titleH = LEDFont.textHeight(pitch: namePitch)
        let titleX = rect.midX - titleW / 2
        let titleY = rect.midY - titleH * 1.05
        ctx.saveGState()
        ctx.setAlpha(alpha)
        if !first.isEmpty {
            LEDFont.drawText(
                ctx,
                text: first,
                origin: CGPoint(x: titleX, y: titleY),
                pitch: namePitch,
                gap: nameGap,
                radius: nameRadius,
                color: scene.theme.name,
                intensity: pulse * scene.intensity,
                scanX: scanX,
                scanWidth: 160,
                bleach: 0.12,
                coreWhite: 0.06,
                drawOffDots: false
            )
        }
        if !last.isEmpty {
            LEDFont.drawText(
                ctx,
                text: last,
                origin: CGPoint(x: titleX + firstW + space, y: titleY),
                pitch: namePitch,
                gap: nameGap,
                radius: nameRadius,
                color: scene.theme.nameSecondary,
                intensity: pulse * scene.intensity,
                scanX: scanX,
                scanWidth: 160,
                bleach: 0.12,
                coreWhite: 0.06,
                drawOffDots: false
            )
        }
        ctx.restoreGState()
    }

    private static func drawTypeName(_ ctx: CGContext, rect: CGRect, scene: RenderScene, alpha: CGFloat) {
        guard alpha > 0.04 else { return }
        let size: CGFloat = min(64, max(40, rect.width * 0.036))
        let nameRect = CGRect(x: rect.minX + 80, y: rect.midY - size * 1.15, width: rect.width - 160, height: size + 8)
        ctx.saveGState()
        ctx.setAlpha(alpha)
        drawSystemText(
            "Mayank Sharma",
            in: ctx,
            rect: nameRect,
            font: .systemFont(ofSize: size, weight: .light),
            color: scene.theme.name,
            alignment: .center
        )
        ctx.restoreGState()
    }

    private static func drawReminder(_ ctx: CGContext, rect: CGRect, scene: RenderScene) {
        let line = scene.reminder
        guard !line.isEmpty else { return }
        let width = min(rect.width - 160, 980)
        let y: CGFloat
        if scene.theme.usesLED {
            let scale = min(rect.width / 2560, rect.height / 1664)
            let namePitch = max(11, 17 * scale)
            y = rect.midY + namePitch * 4.2
        } else {
            y = rect.midY + 18
        }
        drawSystemText(
            line,
            in: ctx,
            rect: CGRect(x: rect.midX - width / 2, y: y, width: width, height: 32),
            font: .systemFont(ofSize: 20, weight: .regular),
            color: scene.theme.body,
            alignment: .center
        )
    }

    private static func fillPanel(_ ctx: CGContext, rect: CGRect, color: RGB) {
        ctx.setFillColor(color.cgColor)
        ctx.fill(rect)
    }

    private static func drawSystemText(
        _ text: String,
        in ctx: CGContext,
        rect: CGRect,
        font: NSFont,
        color: RGB,
        alignment: NSTextAlignment
    ) {
        ctx.saveGState()
        ctx.translateBy(x: rect.minX, y: rect.maxY)
        ctx.scaleBy(x: 1, y: -1)
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(srgbRed: color.r, green: color.g, blue: color.b, alpha: 1),
            .paragraphStyle: style
        ]
        (text as NSString).draw(in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height), withAttributes: attrs)
        ctx.restoreGState()
    }

    private static func makeRep(pixelSize: NSSize, scale: CGFloat, draw: (CGContext) -> Void) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(pixelSize.width),
            pixelsHigh: Int(pixelSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        if let ctx = NSGraphicsContext.current?.cgContext {
            draw(ctx)
        }
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func drawGrid(_ ctx: CGContext, rect: CGRect, color: RGB, step: CGFloat) {
        ctx.setFillColor(color.cgColor)
        var y = rect.minY + 10
        while y < rect.maxY {
            var x = rect.minX + 10
            while x < rect.maxX {
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
                x += step
            }
            y += step
        }
    }

    private static func drawVignette(_ ctx: CGContext, rect: CGRect, background: RGB) {
        let colors = [RGB(0, 0, 0).cgColor, background.cgColor]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
            ctx.saveGState()
            ctx.setAlpha(0.22)
            ctx.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: rect.midX, y: rect.midY),
                startRadius: min(rect.width, rect.height) * 0.3,
                endCenter: CGPoint(x: rect.midX, y: rect.midY),
                endRadius: hypot(rect.width, rect.height) * 0.55,
                options: [.drawsAfterEndLocation]
            )
            ctx.restoreGState()
        }
    }

    private static func drawEqualizer(ctx: CGContext, rect: CGRect, time: TimeInterval, animate: Bool, intensity: CGFloat) {
        let bars = 36
        let margin: CGFloat = max(80, rect.width * 0.14)
        let gap: CGFloat = 5
        let barW = (rect.width - margin * 2 - gap * CGFloat(bars - 1)) / CGFloat(bars)
        let height: CGFloat = 64
        let bottom = rect.maxY - 210
        let colors = [Palette.cyan, Palette.magenta, Palette.green, Palette.amber]
        let t = time
        for b in 0..<bars {
            let wave = 0.2 + 0.7 * abs(sin(CGFloat(b) * 0.33 + CGFloat(t) * .pi * 2))
            let level = min(1, wave) * max(0.4, intensity)
            let barH = max(6, height * level)
            let x = rect.minX + margin + CGFloat(b) * (barW + gap)
            let color = colors[b % colors.count]
            ctx.setFillColor(Palette.bg.mix(color, 0.55 + 0.35 * level).cgColor)
            ctx.fill(CGRect(x: x, y: bottom - barH, width: max(2, barW - 1), height: barH))
        }
    }

    private static func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private static func clockDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: date)
    }

    private static func reveal(_ text: String, start: CGFloat, end: CGFloat, boot: CGFloat) -> String {
        let t = fade(boot, start: start, end: end)
        return String(text.prefix(Int(ceil(CGFloat(text.count) * t))))
    }

    private static func fade(_ boot: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
        if boot <= start { return 0 }
        if boot >= end { return 1 }
        return (boot - start) / (end - start)
    }
}
