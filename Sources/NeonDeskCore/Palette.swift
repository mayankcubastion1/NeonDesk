import CoreGraphics

public struct RGB: Equatable, Sendable {
    public var r: CGFloat
    public var g: CGFloat
    public var b: CGFloat

    public init(_ r: Int, _ g: Int, _ b: Int) {
        self.r = CGFloat(r) / 255
        self.g = CGFloat(g) / 255
        self.b = CGFloat(b) / 255
    }

    public init(unitR: CGFloat, unitG: CGFloat, unitB: CGFloat) {
        self.r = unitR
        self.g = unitG
        self.b = unitB
    }

    public func mix(_ other: RGB, _ t: CGFloat) -> RGB {
        let u = min(1, max(0, t))
        return RGB(
            unitR: r + (other.r - r) * u,
            unitG: g + (other.g - g) * u,
            unitB: b + (other.b - b) * u
        )
    }

    public func glow(_ amount: CGFloat) -> RGB {
        mix(Palette.white, min(0.55, amount))
    }

    public var cgColor: CGColor {
        cgColor(alpha: 1)
    }

    public func cgColor(alpha: CGFloat) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}

public enum Palette {
    public static let bg = RGB(5, 5, 16)
    public static let cyan = RGB(0, 240, 255)
    public static let magenta = RGB(255, 43, 214)
    public static let amber = RGB(255, 176, 0)
    public static let green = RGB(57, 255, 20)
    public static let dim = RGB(18, 22, 40)
    public static let white = RGB(255, 255, 255)
    public static let grid = RGB(12, 16, 32)
}
