import Foundation

enum ThemeStore {
    static let stateURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("NeonDesk/state/theme.txt")

    static func load() -> String {
        let raw = (try? String(contentsOf: stateURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return raw?.isEmpty == false ? raw! : "clock"
    }

    static func save(_ value: String) {
        let dir = stateURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? value.write(to: stateURL, atomically: true, encoding: .utf8)
    }
}

enum CompanionStore {
    static let stateURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("NeonDesk/state/companion.txt")

    struct State {
        var enabled: Bool
        var keepFront: Bool
        var wander: Bool
        var x: CGFloat?
        var y: CGFloat?
    }

    static func load() -> State {
        let raw = (try? String(contentsOf: stateURL, encoding: .utf8)) ?? ""
        var enabled = true
        var keepFront = true
        var wander = true
        var x: CGFloat?
        var y: CGFloat?
        var sawWander = false
        for line in raw.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "enabled":
                enabled = parts[1] != "0" && parts[1].lowercased() != "false"
            case "front":
                keepFront = parts[1] == "1" || parts[1].lowercased() == "true"
            case "wander":
                sawWander = true
                wander = parts[1] != "0" && parts[1].lowercased() != "false"
            case "x":
                x = Double(parts[1]).map { CGFloat($0) }
            case "y":
                y = Double(parts[1]).map { CGFloat($0) }
            default:
                break
            }
        }
        if !raw.isEmpty && !sawWander {
            keepFront = true
            wander = true
        }
        return State(enabled: enabled, keepFront: keepFront, wander: wander, x: x, y: y)
    }

    static func save(enabled: Bool, keepFront: Bool, wander: Bool, x: CGFloat?, y: CGFloat?) {
        let dir = stateURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var lines = [
            "enabled=\(enabled ? 1 : 0)",
            "front=\(keepFront ? 1 : 0)",
            "wander=\(wander ? 1 : 0)"
        ]
        if let x { lines.append("x=\(x)") }
        if let y { lines.append("y=\(y)") }
        try? lines.joined(separator: "\n").write(to: stateURL, atomically: true, encoding: .utf8)
    }
}

enum CursorReminder {
    static func latestTitle() -> String? {
        let db = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Cursor/User/globalStorage/conversation-search.db")
        guard FileManager.default.fileExists(atPath: db.path) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-readonly",
            db.path,
            "SELECT title FROM conversations WHERE is_archived = 0 AND trim(title) != '' ORDER BY updated_at DESC LIMIT 1;"
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }
        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let title = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let title, !title.isEmpty else { return nil }
        return title
    }
}
