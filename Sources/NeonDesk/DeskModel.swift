import AppKit
import Foundation

extension Notification.Name {
    static let neonDeskDidChange = Notification.Name("neonDeskDidChange")
}

final class DeskModel {
    static let shared = DeskModel()

    private(set) var mode: DeskMode = .work
    private(set) var followClock = true
    private(set) var onBattery = false
    private(set) var weather: WeatherSnapshot?
    private(set) var spotify: SpotifySnapshot?
    private(set) var lyrics: LyricSheet?
    private(set) var transit: TransitEvent?
    private(set) var taskTitle: String?
    private(set) var companionEnabled = true
    private(set) var companionKeepFront = true
    private(set) var companionWander = true
    private(set) var companionX: CGFloat?
    private(set) var companionY: CGFloat?
    private(set) var companionReaction: CompanionReaction = .none
    private(set) var companionPokeText: String?
    private var pinnedTheme: ThemeID?
    private var bootStart = CACurrentMediaTime()
    private var showDeadline: TimeInterval?
    private var lastHour = -1
    private var weatherTimer: Timer?
    private var tickTimer: Timer?
    private var powerTimer: Timer?
    private var reminderTimer: Timer?
    private var lyricsKey: String?
    private var lyricsAttempted: String?
    private var lyricsAttemptedAt: TimeInterval = 0
    private var companionReactionUntil: TimeInterval = 0

    var themeID: ThemeID {
        if followClock { return ThemeID.forDate(Date()) }
        return pinnedTheme ?? ThemeID.forDate(Date())
    }

    var theme: Theme { Theme.palette(themeID) }

    var reminder: String {
        DayPart.reminder(for: Date(), task: taskTitle)
    }

    var boot: CGFloat {
        CGFloat(min(1, (CACurrentMediaTime() - bootStart) / 4.0))
    }

    var intensity: CGFloat {
        switch mode {
        case .show: return 1
        case .work: return onBattery ? 0.82 : 0.9
        case .off: return 0
        }
    }

    var shouldAnimate: Bool {
        mode == .show || (mode == .work && !onBattery && theme.showsEqualizer)
    }

    var framesPerSecond: Double {
        switch mode {
        case .show: return 16
        case .work: return onBattery || !theme.showsEqualizer ? 0.25 : 8
        case .off: return 0
        }
    }

    var companionFramesPerSecond: Double {
        guard companionEnabled, mode != .off else { return 0 }
        return onBattery ? 8 : 12
    }

    var companionVisible: Bool {
        companionEnabled && mode != .off
    }

    func start() {
        applyStoredTheme()
        applyStoredCompanion()
        onBattery = PowerService.onBattery()
        transit = TransitCalendar.current()
        applySpotify(SpotifyService.snapshot())
        taskTitle = CursorReminder.latestTitle()
        lastHour = Calendar.current.component(.hour, from: Date())
        replayBoot()
        Task { await refreshWeather() }
        weatherTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { await self?.refreshWeather() }
        }
        powerTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.refreshPowerAndTransit()
        }
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        reminderTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            self?.refreshReminder()
        }
        for timer in [weatherTimer, powerTimer, tickTimer, reminderTimer].compactMap({ $0 }) {
            RunLoop.main.add(timer, forMode: .common)
        }
        refreshStills()
        notify()
    }

    func loadReminder() {
        taskTitle = CursorReminder.latestTitle()
    }

    func applyStoredTheme() {
        let stored = ThemeStore.load()
        if stored == "clock" {
            followClock = true
            pinnedTheme = nil
        } else if let id = ThemeID(rawValue: stored) {
            followClock = false
            pinnedTheme = id
        } else {
            followClock = true
            pinnedTheme = nil
        }
    }

    func followTheClock() {
        followClock = true
        pinnedTheme = nil
        ThemeStore.save("clock")
        replayBoot()
        refreshStills()
        notify()
    }

    func applyStoredCompanion() {
        let stored = CompanionStore.load()
        companionEnabled = stored.enabled
        companionKeepFront = stored.keepFront
        companionWander = stored.wander
        companionX = stored.x
        companionY = stored.y
    }

    func persistCompanion() {
        CompanionStore.save(
            enabled: companionEnabled,
            keepFront: companionKeepFront,
            wander: companionWander,
            x: companionX,
            y: companionY
        )
    }

    func setCompanionEnabled(_ enabled: Bool) {
        companionEnabled = enabled
        persistCompanion()
        notify()
    }

    func setCompanionKeepFront(_ keepFront: Bool) {
        companionKeepFront = keepFront
        persistCompanion()
        notify()
    }

    func setCompanionWander(_ wander: Bool) {
        companionWander = wander
        persistCompanion()
        notify()
    }

    func setCompanionOrigin(x: CGFloat, y: CGFloat, persist: Bool = true) {
        companionX = x
        companionY = y
        if persist { persistCompanion() }
    }

    func setCompanionReaction(_ reaction: CompanionReaction, seconds: TimeInterval) {
        companionReaction = reaction
        companionReactionUntil = Date().timeIntervalSinceReferenceDate + seconds
        if reaction == .carried || reaction == .land {
            companionPokeText = nil
        }
        notify()
    }

    func clearCompanionReaction() {
        companionReaction = .none
        companionReactionUntil = 0
        companionPokeText = nil
    }

    func pokeCompanion() {
        if spotify?.playing == true {
            SpotifyService.playPause()
            applySpotify(SpotifyService.snapshot())
            notify()
            return
        }
        if CompanionPose.forDate(Date()) == .sleep {
            companionReaction = .sitUp
            companionReactionUntil = Date().timeIntervalSinceReferenceDate + 4
        } else {
            companionReaction = Bool.random() ? .wave : .jump
            companionReactionUntil = Date().timeIntervalSinceReferenceDate + 2.4
        }
        companionPokeText = weather?.display ?? DayPart.label(for: Date())
        notify()
    }

    func currentReaction() -> CompanionReaction {
        Date().timeIntervalSinceReferenceDate >= companionReactionUntil ? .none : companionReaction
    }

    func lyricMoment(at hostTime: TimeInterval = Date().timeIntervalSinceReferenceDate) -> LyricMoment? {
        guard let spotify else { return nil }
        return lyrics?.moment(at: spotify.playhead(at: hostTime))
    }

    func pinTheme(_ id: ThemeID) {
        followClock = false
        pinnedTheme = id
        ThemeStore.save(id.rawValue)
        replayBoot()
        refreshStills()
        notify()
    }

    func setMode(_ mode: DeskMode) {
        self.mode = mode
        if mode == .show {
            showDeadline = CACurrentMediaTime() + 60
        } else {
            showDeadline = nil
        }
        notify()
    }

    func toggleShow() {
        setMode(mode == .show ? .work : .show)
    }

    func replayBoot() {
        bootStart = CACurrentMediaTime()
        notify()
    }

    func scene() -> RenderScene {
        RenderScene(
            now: Date(),
            mediaTime: CACurrentMediaTime(),
            boot: boot,
            intensity: intensity,
            animate: shouldAnimate,
            themeID: themeID,
            reminder: reminder
        )
    }

    func stillScene() -> RenderScene {
        RenderScene.still(date: Date(), themeID: themeID, reminder: reminder)
    }

    func refreshStills() {
        if (try? WallpaperService.writeStills(scene: stillScene())) != nil {
            WallpaperService.applyStills()
        }
    }

    private func tick() {
        if mode == .show, let showDeadline, CACurrentMediaTime() >= showDeadline {
            setMode(.work)
            return
        }
        applySpotify(SpotifyService.snapshot())
        expireCompanionReaction()
        let hour = Calendar.current.component(.hour, from: Date())
        if followClock, hour != lastHour {
            lastHour = hour
            replayBoot()
            refreshStills()
        }
        lastHour = hour
        notify()
    }

    private func refreshReminder() {
        taskTitle = CursorReminder.latestTitle()
        notify()
    }

    private func refreshPowerAndTransit() {
        onBattery = PowerService.onBattery()
        transit = TransitCalendar.current()
        notify()
    }

    private func refreshWeather() async {
        if let snapshot = await WeatherService.fetch() {
            await MainActor.run {
                self.weather = snapshot
                self.notify()
            }
        }
    }

    private func expireCompanionReaction() {
        guard companionReaction != .none, Date().timeIntervalSinceReferenceDate >= companionReactionUntil else { return }
        companionReaction = .none
        companionPokeText = nil
    }

    private func applySpotify(_ snapshot: SpotifySnapshot?) {
        spotify = snapshot
        guard let snapshot else {
            lyrics = nil
            lyricsKey = nil
            lyricsAttempted = nil
            lyricsAttemptedAt = 0
            return
        }
        let key = snapshot.identity
        let hasLines = lyrics?.trackID == key && !(lyrics?.lines.isEmpty ?? true)
        if hasLines { return }
        let now = Date().timeIntervalSinceReferenceDate
        let recentlyTried = lyricsAttempted == key && now - lyricsAttemptedAt < 20
        if recentlyTried { return }
        if lyricsKey != key {
            lyrics = nil
            lyricsKey = key
        }
        lyricsAttempted = key
        lyricsAttemptedAt = now
        Task { await self.refreshLyrics(for: snapshot, key: key) }
    }

    private func refreshLyrics(for snapshot: SpotifySnapshot, key: String) async {
        let lines = await LyricsService.fetch(
            artist: snapshot.artist,
            title: snapshot.title,
            album: snapshot.album,
            duration: snapshot.duration
        )
        await MainActor.run {
            guard self.lyricsKey == key else { return }
            self.lyrics = LyricSheet(trackID: key, lines: lines)
            self.notify()
        }
    }

    private func notify() {
        NotificationCenter.default.post(name: .neonDeskDidChange, object: self)
    }
}
