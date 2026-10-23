# NeonDesk

```
  ███╗   ██╗███████╗ ██████╗ ███╗   ██╗
  ████╗  ██║██╔════╝██╔═══██╗████╗  ██║
  ██╔██╗ ██║█████╗  ██║   ██║██╔██╗ ██║
  ██║╚██╗██║██╔══╝  ██║   ██║██║╚██╗██║
  ██║ ╚████║███████╗╚██████╔╝██║ ╚████║
  ╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝  ╚═══╝
            D  E  S  K
```

A live neon desk for macOS. The wallpaper breathes with the hour. Corner widgets stay out of your work. A stick figure wanders over your apps, sits, sleeps, and sings whatever Spotify is playing.

Built for an Apple Silicon Mac. No accounts. No cloud of yours. Nothing private on the glass.

[Install](#install) · [Companion](#the-companion) · [Privacy](#privacy) · [Source](#source) · [Roadmap](#roadmap)

---

## What you get

| | |
| --- | --- |
| **Themes that follow the clock** | Paper at dawn, Terminal through the morning, Espresso after lunch, Quiet Night, Observatory, Monsoon after midnight. Neon is manual only. |
| **Desktop widgets** | LED clock, Gurugram weather, a Spotify chip when the app is running, a one-line sky note when a transit window is active. |
| **A roaming singer** | One stick figure, on top of your apps. He walks, sits, reads, sleeps. When a track is playing he takes the mic and the current lyric leaves it into a thought cloud. |
| **Show mode** | Control-Option-N lifts the widgets and brightens the scene for sixty seconds. |
| **Screensaver** | The same world, on demand from the menu bar. |

Work mode keeps the animation behind your windows. Off hides everything.

---

## Install

Needs **macOS 14+**, **Apple Silicon**, and the **Xcode Command Line Tools**.

```bash
git clone https://github.com/mayankcubastion1/NeonDesk.git
cd NeonDesk
./scripts/install.sh
```

That builds the app and the screensaver, copies them to `~/Applications` and `~/Library/Screen Savers`, writes still wallpapers, and launches NeonDesk. A menu extra appears in the bar.

The first Spotify read will ask for Automation permission. Allow it if you want lyrics and play/pause.

macOS may warn that the binary is ad-hoc signed. Build it yourself with the script above, or right-click the app and choose Open.

```bash
./scripts/uninstall.sh
```

puts your wallpaper, dock magnification, login item, and screensaver back.

---

## The companion

He floats above Cursor, Chrome, everything. After a rest he walks to a new spot on either display, then settles. Pickup is two-dimensional: grab him and his legs dangle. Drop him and he lands, waits a few seconds, and wanders again.

| When | He |
| --- | --- |
| 05:00–08:00 | stretches |
| 08:00–13:00 | types, coffee on the floor |
| 13:00–17:00 | sits |
| 17:00–21:00 | reads |
| 21:00–23:00 | looks up |
| 23:00–05:00 | sleeps, `z` in the cloud |
| Spotify playing | sings, lyrics timed to the playhead |

Click him to play/pause, or to wake a wave if nothing is playing. Menu checks:

- **Companion** — show or hide him
- **Keep in front** — over apps (default) or back on the desktop
- **Wander** — let him walk, or pin him where you dropped him

Lyrics come from [LRCLIB](https://lrclib.net), locked to Spotify’s `player position`. If a track has no synced lines, the cloud shows the title and he still sings.

---

## Themes

The hour picks the palette unless you pin one.

```
05  Paper          warm off-white
09  Terminal       one muted green
13  Espresso       dark roast
17  Quiet Night    near-black, no bars
21  Observatory    navy and thin gold
00  Monsoon        slate, weather first
    Neon           cyan / magenta — menu only
```

---

## Privacy

NeonDesk is a local menu-bar app. It does not create an account and it does not send your files anywhere.

- **Spotify** — title, artist, album, duration, and playhead via AppleScript on this Mac
- **Lyrics** — one request to LRCLIB per track
- **Weather** — Open-Meteo for Gurugram
- **Reminder line** — the time of day, plus the title of the latest Cursor chat if that database is on disk. Bodies stay off the desktop.

No revenue sheets, resumes, client names, chat logs, or photos. The personal bits that can appear are ones you already put on a public page or made for the desk: the wordmark, the city, the song that is playing, a short sky line.

---

## Source

```
NeonDesk/
  Sources/NeonDesk/          app, widgets, companion, Spotify, weather
  Sources/NeonDeskCore/      LED face, themes, stick figure, renderer
  Sources/NeonDeskSaver/     screensaver bundle
  scripts/install.sh
  scripts/uninstall.sh
  build.sh
```

`swiftc` only. No Xcode project, no SwiftPM packages, no telemetry.

---

## Roadmap

The next world is a **lobby**: more than one stick figure on the same glass, meeting in real time, reacting to each other and to the song. Wander becomes a room. That is not in this tree yet.

---

## License

[MIT](LICENSE). Mayank Sharma, 2026.
