import Foundation

public enum ThemeID: String, CaseIterable, Sendable {
    case paper
    case terminal
    case espresso
    case quietNight
    case observatory
    case monsoon
    case neon

    public var title: String {
        switch self {
        case .paper: return "Paper"
        case .terminal: return "Terminal"
        case .espresso: return "Espresso"
        case .quietNight: return "Quiet Night"
        case .observatory: return "Observatory"
        case .monsoon: return "Monsoon"
        case .neon: return "Neon"
        }
    }

    public static func forHour(_ hour: Int) -> ThemeID {
        switch hour {
        case 5..<9: return .paper
        case 9..<13: return .terminal
        case 13..<17: return .espresso
        case 17..<21: return .quietNight
        case 21..<24: return .observatory
        default: return .monsoon
        }
    }

    public static func forDate(_ date: Date) -> ThemeID {
        forHour(Calendar.current.component(.hour, from: date))
    }

    public static func resolved(at date: Date = Date()) -> ThemeID {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("NeonDesk/state/theme.txt")
        let raw = (try? String(contentsOf: url, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, raw != "clock", let id = ThemeID(rawValue: raw) {
            return id
        }
        return forDate(date)
    }
}

public struct Theme: Sendable {
    public var id: ThemeID
    public var background: RGB
    public var name: RGB
    public var nameSecondary: RGB
    public var body: RGB
    public var accent: RGB
    public var panel: RGB
    public var grid: RGB
    public var usesLED: Bool
    public var showsEqualizer: Bool
    public var showsGrid: Bool

    public static func palette(_ id: ThemeID) -> Theme {
        switch id {
        case .paper:
            return Theme(
                id: .paper,
                background: RGB(244, 238, 226),
                name: RGB(38, 33, 28),
                nameSecondary: RGB(38, 33, 28),
                body: RGB(92, 82, 70),
                accent: RGB(142, 96, 58),
                panel: RGB(236, 228, 212),
                grid: RGB(228, 220, 204),
                usesLED: false,
                showsEqualizer: false,
                showsGrid: false
            )
        case .terminal:
            return Theme(
                id: .terminal,
                background: RGB(7, 9, 7),
                name: RGB(126, 168, 126),
                nameSecondary: RGB(126, 168, 126),
                body: RGB(88, 118, 88),
                accent: RGB(126, 168, 126),
                panel: RGB(14, 18, 14),
                grid: RGB(18, 24, 18),
                usesLED: false,
                showsEqualizer: false,
                showsGrid: true
            )
        case .espresso:
            return Theme(
                id: .espresso,
                background: RGB(28, 20, 16),
                name: RGB(236, 220, 196),
                nameSecondary: RGB(236, 220, 196),
                body: RGB(176, 148, 118),
                accent: RGB(184, 112, 64),
                panel: RGB(40, 28, 22),
                grid: RGB(46, 32, 24),
                usesLED: false,
                showsEqualizer: false,
                showsGrid: false
            )
        case .quietNight:
            return Theme(
                id: .quietNight,
                background: RGB(8, 10, 14),
                name: RGB(176, 210, 220),
                nameSecondary: RGB(176, 210, 220),
                body: RGB(148, 176, 186),
                accent: RGB(90, 170, 186),
                panel: RGB(16, 20, 26),
                grid: RGB(20, 26, 32),
                usesLED: false,
                showsEqualizer: false,
                showsGrid: false
            )
        case .observatory:
            return Theme(
                id: .observatory,
                background: RGB(10, 14, 28),
                name: RGB(228, 210, 160),
                nameSecondary: RGB(228, 210, 160),
                body: RGB(156, 164, 188),
                accent: RGB(198, 168, 96),
                panel: RGB(16, 22, 40),
                grid: RGB(22, 28, 48),
                usesLED: false,
                showsEqualizer: false,
                showsGrid: false
            )
        case .monsoon:
            return Theme(
                id: .monsoon,
                background: RGB(18, 28, 38),
                name: RGB(198, 214, 222),
                nameSecondary: RGB(198, 214, 222),
                body: RGB(140, 164, 176),
                accent: RGB(110, 154, 176),
                panel: RGB(26, 38, 50),
                grid: RGB(32, 46, 58),
                usesLED: false,
                showsEqualizer: false,
                showsGrid: false
            )
        case .neon:
            return Theme(
                id: .neon,
                background: Palette.bg,
                name: Palette.cyan,
                nameSecondary: Palette.magenta,
                body: Palette.amber,
                accent: Palette.green,
                panel: RGB(8, 8, 22),
                grid: Palette.grid,
                usesLED: true,
                showsEqualizer: true,
                showsGrid: true
            )
        }
    }
}

public enum DayPart {
    public static func label(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "MORNING"
        case 12..<17: return "AFTERNOON"
        case 17..<21: return "EVENING"
        default: return "LATE"
        }
    }

    public static func verb(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: return "PICK UP"
        case 12..<17: return "STILL OPEN:"
        case 17..<21: return "CLOSE"
        default: return "PARK"
        }
    }

    public static func reminder(for date: Date, task: String?) -> String {
        let part = label(for: date)
        guard let task, !task.isEmpty else { return part }
        return "\(part). \(verb(for: date)) \(task.uppercased())"
    }
}
