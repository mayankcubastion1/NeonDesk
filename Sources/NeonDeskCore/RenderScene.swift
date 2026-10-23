import Foundation

public struct WeatherSnapshot: Sendable, Equatable {
    public var celsius: Int
    public var label: String

    public init(celsius: Int, label: String) {
        self.celsius = celsius
        self.label = label
    }

    public var display: String {
        "\(celsius)°  \(label.capitalized)"
    }
}

public struct SpotifySnapshot: Sendable, Equatable {
    public var playing: Bool
    public var artist: String
    public var title: String
    public var album: String
    public var trackID: String
    public var duration: TimeInterval
    public var position: TimeInterval
    public var sampledAt: TimeInterval

    public init(
        playing: Bool,
        artist: String,
        title: String,
        album: String = "",
        trackID: String = "",
        duration: TimeInterval = 0,
        position: TimeInterval = 0,
        sampledAt: TimeInterval = 0
    ) {
        self.playing = playing
        self.artist = artist
        self.title = title
        self.album = album
        self.trackID = trackID
        self.duration = duration
        self.position = position
        self.sampledAt = sampledAt
    }

    public var line: String {
        let raw = "\(artist)  \(title)"
        return raw.trimmingCharacters(in: .whitespaces).isEmpty ? "Spotify" : raw
    }

    public var identity: String {
        if !trackID.isEmpty { return trackID }
        return "\(artist)\u{1e}\(title)\u{1e}\(album)"
    }

    public func playhead(at hostTime: TimeInterval) -> TimeInterval {
        let raw = playing ? position + (hostTime - sampledAt) : position
        if duration > 0 {
            return min(duration, max(0, raw))
        }
        return max(0, raw)
    }
}

public struct LyricLine: Sendable, Equatable {
    public var time: TimeInterval
    public var text: String

    public init(time: TimeInterval, text: String) {
        self.time = time
        self.text = text
    }
}

public struct LyricSheet: Sendable, Equatable {
    public var trackID: String
    public var lines: [LyricLine]

    public init(trackID: String, lines: [LyricLine]) {
        self.trackID = trackID
        self.lines = lines
    }

    public func moment(at playhead: TimeInterval) -> LyricMoment? {
        guard !lines.isEmpty else { return nil }
        var index = 0
        for i in lines.indices where lines[i].time <= playhead {
            index = i
        }
        let current = lines[index]
        let nextTime = index + 1 < lines.count ? lines[index + 1].time : current.time + 4
        let span = max(0.25, nextTime - current.time)
        let progress = CGFloat(min(1, max(0, (playhead - current.time) / span)))
        let words = current.text.split(whereSeparator: \.isWhitespace).map(String.init)
        let word: String
        if words.isEmpty {
            word = ""
        } else {
            word = words[min(words.count - 1, Int(floor(progress * CGFloat(words.count))))]
        }
        return LyricMoment(line: current.text, word: word, progress: progress)
    }
}

public struct LyricMoment: Sendable, Equatable {
    public var line: String
    public var word: String
    public var progress: CGFloat

    public init(line: String, word: String, progress: CGFloat) {
        self.line = line
        self.word = word
        self.progress = progress
    }
}

public struct TransitEvent: Sendable, Equatable {
    public var label: String

    public init(label: String) {
        self.label = label
    }
}

public enum DeskMode: String, Sendable {
    case work
    case show
    case off
}

public struct RenderScene: Sendable {
    public var now: Date
    public var mediaTime: TimeInterval
    public var boot: CGFloat
    public var intensity: CGFloat
    public var animate: Bool
    public var themeID: ThemeID
    public var firstName: String
    public var lastName: String
    public var reminder: String

    public var theme: Theme { Theme.palette(themeID) }

    public init(
        now: Date,
        mediaTime: TimeInterval,
        boot: CGFloat,
        intensity: CGFloat,
        animate: Bool,
        themeID: ThemeID,
        firstName: String = "MAYANK",
        lastName: String = "SHARMA",
        reminder: String
    ) {
        self.now = now
        self.mediaTime = mediaTime
        self.boot = min(1, max(0, boot))
        self.intensity = intensity
        self.animate = animate
        self.themeID = themeID
        self.firstName = firstName
        self.lastName = lastName
        self.reminder = reminder
    }

    public static func still(date: Date = Date(), themeID: ThemeID? = nil, reminder: String = "") -> RenderScene {
        let theme = themeID ?? ThemeID.forDate(date)
        return RenderScene(
            now: date,
            mediaTime: 8.4,
            boot: 1,
            intensity: 0.9,
            animate: false,
            themeID: theme,
            reminder: reminder.isEmpty ? DayPart.reminder(for: date, task: nil) : reminder
        )
    }
}
