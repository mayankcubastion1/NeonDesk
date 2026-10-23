import AppKit
import Foundation
import IOKit.ps

struct WeatherService {
    static func fetch() async -> WeatherSnapshot? {
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=28.4595&longitude=77.0266&current=temperature_2m,weather_code&timezone=Asia%2FKolkata") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any]
            else { return nil }
            let temp = (current["temperature_2m"] as? NSNumber)?.doubleValue ?? (current["temperature_2m"] as? Double) ?? 0
            let code = (current["weather_code"] as? NSNumber)?.intValue ?? (current["weather_code"] as? Int) ?? 0
            return WeatherSnapshot(celsius: Int(temp.rounded()), label: label(for: code))
        } catch {
            return nil
        }
    }

    private static func label(for code: Int) -> String {
        switch code {
        case 0: return "CLEAR"
        case 1, 2: return "FAIR"
        case 3: return "CLOUD"
        case 45, 48: return "FOG"
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return "RAIN"
        case 71, 73, 75, 77, 85, 86: return "SNOW"
        case 95, 96, 99: return "STORM"
        default: return "HAZE"
        }
    }
}

enum SpotifyService {
    static func snapshot() -> SpotifySnapshot? {
        let script = """
        tell application "System Events"
          if not (exists process "Spotify") then return "off"
        end tell
        tell application "Spotify"
          set s to player state as string
          try
            set t to name of current track
            set a to artist of current track
            set alb to album of current track
            set tid to id of current track
            set dur to duration of current track
            set pos to player position
          on error
            return s & tab & "" & tab & "" & tab & "" & tab & "" & tab & "0" & tab & "0"
          end try
          return s & tab & a & tab & t & tab & alb & tab & tid & tab & (dur as string) & tab & (pos as string)
        end tell
        """
        guard let result = runAppleScript(script), result != "off" else { return nil }
        let parts = result.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
        let state = parts[safe: 0] ?? ""
        let artist = parts[safe: 1] ?? ""
        let title = parts[safe: 2] ?? ""
        let album = parts[safe: 3] ?? ""
        let trackID = parts[safe: 4] ?? ""
        let durationMs = Double(parts[safe: 5] ?? "") ?? 0
        let position = Double(parts[safe: 6] ?? "") ?? 0
        let duration = durationMs > 1000 ? durationMs / 1000 : durationMs
        return SpotifySnapshot(
            playing: state == "playing",
            artist: artist,
            title: title,
            album: album,
            trackID: trackID,
            duration: duration,
            position: position,
            sampledAt: Date().timeIntervalSinceReferenceDate
        )
    }

    static func playPause() {
        _ = runAppleScript("tell application \"System Events\"\nif exists process \"Spotify\" then tell application \"Spotify\" to playpause\nend tell")
    }

    private static func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let output = script?.executeAndReturnError(&error)
        if error != nil { return nil }
        return output?.stringValue
    }
}

enum LyricsService {
    static func fetch(artist: String, title: String, album: String, duration: TimeInterval) async -> [LyricLine] {
        guard !artist.isEmpty, !title.isEmpty else { return [] }
        if let lines = await get(artist: artist, title: title, album: album, duration: duration), !lines.isEmpty {
            return lines
        }
        return await search(artist: artist, title: title, duration: duration) ?? []
    }

    private static func get(artist: String, title: String, album: String, duration: TimeInterval) async -> [LyricLine]? {
        var items = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title)
        ]
        if !album.isEmpty {
            items.append(URLQueryItem(name: "album_name", value: album))
        }
        if duration > 1 {
            items.append(URLQueryItem(name: "duration", value: String(Int(duration.rounded()))))
        }
        guard let json = await jsonObject(path: "/api/get", items: items) as? [String: Any] else { return nil }
        return lines(from: json)
    }

    private static func search(artist: String, title: String, duration: TimeInterval) async -> [LyricLine]? {
        let items = [
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "track_name", value: title)
        ]
        guard let rows = await jsonObject(path: "/api/search", items: items) as? [[String: Any]] else { return nil }
        var best: [LyricLine] = []
        var bestDelta = TimeInterval.greatestFiniteMagnitude
        for row in rows {
            guard let lines = lines(from: row), lines.count > 1 else { continue }
            let rowDuration = (row["duration"] as? NSNumber)?.doubleValue ?? (row["duration"] as? Double) ?? 0
            let delta = duration > 1 && rowDuration > 1 ? abs(rowDuration - duration) : 0
            if best.isEmpty || delta < bestDelta {
                best = lines
                bestDelta = delta
            }
        }
        return best.isEmpty ? nil : best
    }

    private static func lines(from json: [String: Any]) -> [LyricLine]? {
        if let synced = json["syncedLyrics"] as? String {
            let parsed = parseLRC(synced)
            if parsed.count > 1 { return parsed }
        }
        return nil
    }

    private static func jsonObject(path: String, items: [URLQueryItem]) async -> Any? {
        var components = URLComponents(string: "https://lrclib.net\(path)")
        components?.queryItems = items
        guard let url = components?.url else { return nil }
        var request = URLRequest(url: url)
        request.setValue("NeonDesk/1.0 (desktop companion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                return nil
            }
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            return nil
        }
    }

    static func parseLRC(_ raw: String) -> [LyricLine] {
        let pattern = #"\[(\d+):(\d+(?:\.\d+)?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var lines: [LyricLine] = []
        for row in raw.split(whereSeparator: \.isNewline) {
            let text = String(row)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)
            guard let first = matches.first,
                  let minRange = Range(first.range(at: 1), in: text),
                  let secRange = Range(first.range(at: 2), in: text)
            else { continue }
            let minutes = Double(text[minRange]) ?? 0
            let seconds = Double(text[secRange]) ?? 0
            let lyric = regex.stringByReplacingMatches(in: text, range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !lyric.isEmpty else { continue }
            lines.append(LyricLine(time: minutes * 60 + seconds, text: lyric))
        }
        return lines.sorted { $0.time < $1.time }
    }
}

enum PowerService {
    static func onBattery() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }
        for source in list {
            if let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
               let state = info[kIOPSPowerSourceStateKey] as? String
            {
                return state == kIOPSBatteryPowerValue
            }
        }
        return false
    }
}

enum WallpaperService {
    static let stillDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Pictures/NeonDesk", isDirectory: true)

    static func stillURL(for size: CGSize) -> URL {
        let name = "wallpaper-\(Int(size.width))x\(Int(size.height)).png"
        return stillDir.appendingPathComponent(name)
    }

    static func writeStills(scene: RenderScene = .still()) throws -> [URL] {
        let sizes = [CGSize(width: 2560, height: 1664), CGSize(width: 1920, height: 1080)]
        var urls: [URL] = []
        for size in sizes {
            let url = stillURL(for: size)
            try LEDRenderer.writeStill(size: size, to: url, scene: scene)
            urls.append(url)
        }
        return urls
    }

    static func applyStills() {
        for screen in NSScreen.screens {
            let pixelWidth = screen.frame.width * screen.backingScaleFactor
            let url: URL
            if pixelWidth >= 2400 {
                url = stillURL(for: CGSize(width: 2560, height: 1664))
            } else {
                url = stillURL(for: CGSize(width: 1920, height: 1080))
            }
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [
                .imageScaling: NSNumber(value: NSImageScaling.scaleProportionallyUpOrDown.rawValue),
                .allowClipping: true
            ])
        }
    }

    static func backupCurrent(to stateDir: URL) {
        var lines: [String] = []
        for (index, screen) in NSScreen.screens.enumerated() {
            if let url = NSWorkspace.shared.desktopImageURL(for: screen) {
                lines.append("\(index)\t\(url.path)")
            }
        }
        let dest = stateDir.appendingPathComponent("wallpaper-backup.txt")
        try? FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        try? lines.joined(separator: "\n").write(to: dest, atomically: true, encoding: .utf8)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
