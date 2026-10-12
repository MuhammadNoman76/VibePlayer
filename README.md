# VibePlayer

A Windows desktop media player with a YouTube-style interface, built on **LibVLC**, the engine inside VLC.
It plays the formats VLC plays: MKV, MP4, AVI, MOV, WMV, FLV, WebM, TS, H.264/H.265/AV1/VP9, AC3/DTS,
FLAC, network streams and more, with hardware decoding.

## Download

Pick the installer for your PC. Not sure? Most PCs need the first one.

| Your Windows | CPU | Download | Size |
|---|---|---|---|
| **Windows 10 / 11**, 64-bit (most PCs) | Intel / AMD 64-bit | [VibePlayer-Setup-1.0.1-x64.exe](release/VibePlayer-Setup-1.0.1-x64.exe) | 64.0 MB |
| **Windows 11 / 10 on ARM** (Snapdragon, Surface Pro X…) | ARM64 | [VibePlayer-Setup-1.0.1-arm64.exe](release/VibePlayer-Setup-1.0.1-arm64.exe) | 55.5 MB |
| **Windows 10**, 32-bit | Intel / AMD 32-bit | [VibePlayer-Setup-1.0.1-x86.exe](release/VibePlayer-Setup-1.0.1-x86.exe) | 59.3 MB |
| **Windows 7 SP1 / 8.1** (Windows 8 needs the free 8.1 update) | Intel / AMD, 32- or 64-bit | [VibePlayer-Setup-1.0.1-win7-8.exe](release/VibePlayer-Setup-1.0.1-win7-8.exe) | 43.3 MB |

- The Windows 10/11 installers include everything they need. The Windows 7/8.1 edition uses Microsoft
  **.NET Framework 4.8**, which most of those PCs already have from Windows Update; setup tells you if it's
  missing and offers to open Microsoft's download page. It installs the 64- or 32-bit VLC engine to match
  your Windows.
- Find your Windows version and type in *Settings › System › About* (Windows 7/8.1: *Control Panel › System*).
- Windows XP and Vista aren't supported.
- SHA-256 checksums are in [release/SHA256SUMS.txt](release/SHA256SUMS.txt). To check a download, run
  `Get-FileHash .\VibePlayer-Setup-1.0.1-x64.exe` in PowerShell (Windows 7: `certutil -hashfile <file> SHA256`)
  and compare the result with the list.
- The installers aren't code-signed, so Windows SmartScreen may say *"Windows protected your PC"*.
  Click **More info › Run anyway**.
- The ARM64 edition comes without VLC's pre-built plugin cache, so VLC looks through its plugins each time
  the player starts, which takes a little longer. (Installed just for you, the player builds the cache on
  its first run and starts quickly after that.)

## Install

Run the installer for your PC. Setup can:

- install for all users (Program Files, needs admin) or only for you
- add VibePlayer to **Open with** for video and audio files, and list it under
  *Settings › Apps › Default apps*. To make it the default, right-click a video, choose
  **Open with › Choose another app › VibePlayer** and tick **Always**.
- add **Play with VibePlayer** to the folder right-click menu
- create a desktop shortcut

Installing a newer version, or another edition, replaces the one you have; your settings are kept.

## Highlights

- **Press and hold on the right half of the video for 2x speed.** Release to go back to the normal
  speed. Holding the right mouse button anywhere does the same.
- YouTube-style controls: red progress bar with hover time and scrubbing, pill buttons, autoplay toggle,
  CC, a settings menu (loop, speed, subtitles, audio track, aspect ratio, snapshot), miniplayer and full screen.
- **Skip scenes without editing the file:** mark parts such as 0:00–0:10 or 34:05–44:54 and the player
  jumps over them every time. Use Settings (gear) › Skip scenes, the right-click menu, or press `[` at the
  start and `]` at the end. Skipped parts show in yellow on the progress bar.
- Clicking the video does nothing (no accidental pause). Double-click toggles full screen.
- Mouse wheel over the progress bar or time seeks ±5 s; anywhere else on the video it changes the volume.
- Click the time to switch between elapsed and remaining time.
- Remembers where you stopped each long video and resumes from there.
- Plays the rest of the folder in order (autoplay), and drag & drop for files, folders, subtitles and URLs.
- Several windows: if VibePlayer is already open it asks whether to use that window or open a new one
  (you can tick "Remember my choice", and change it later in the right-click menu).
- Right-click menu with recent files, tracks, aspect ratio, always on top, and more.

## Keyboard shortcuts

| Keys | Action |
|---|---|
| Space / K | Play / pause |
| J / L | Back / forward 10 s |
| ← / → (Ctrl: 1 min) | Back / forward 5 s |
| ↑ / ↓, mouse wheel | Volume |
| M | Mute |
| F, double-click, Alt+Enter | Full screen (Esc to leave) |
| 0–9, Home / End | Jump to 0–90 %, start / end |
| Shift+> / Shift+< | Faster / slower |
| . / , | Next / previous frame (paused) |
| C, V, B | Subtitles on/off, cycle subtitle, cycle audio track |
| G / H | Subtitle sync earlier / later |
| [ / ] | Start / end a skipped part |
| A | Cycle aspect ratio |
| I / T | Miniplayer / always on top |
| Shift+N / Shift+P | Next / previous file |
| Shift+S | Snapshot (saved to Pictures\VibePlayer) |
| Ctrl+O / Ctrl+F / Ctrl+N | Open file / folder / network stream |
| ? | Shortcut help |

## Build from source

Requirements: [.NET 10 SDK](https://dot.net) and [Inno Setup 6](https://jrsoftware.org/isdl.php) (for the installers).

```powershell
powershell -ExecutionPolicy Bypass -File build.ps1                   # all four installers -> dist\
powershell -ExecutionPolicy Bypass -File build.ps1 -Editions x64     # just one edition (x64, arm64, x86, legacy)
powershell -ExecutionPolicy Bypass -File build.ps1 -SkipInstaller    # apps only -> publish\<edition>
```

One codebase, two targets: **.NET 10** (Windows 10/11, published self-contained for x64, ARM64 and x86,
so the PC doesn't need .NET installed) and **.NET Framework 4.8** (the `legacy` edition for Windows 7 SP1 / 8.1,
one AnyCPU app that carries both the 32- and 64-bit VLC engines). `dist\SHA256SUMS.txt` lists the checksums
of the installers.

The build also pre-generates VLC's plugin cache (`plugins.dat`) for the x64, x86 and Windows 7/8.1 editions,
so the player starts in under a second instead of scanning about 320 plugin DLLs on every launch. ARM64
programs can't run on an x64 build PC, so the ARM64 edition ships without it.

## Project layout

```
src/VibePlayer/
  Core/        PlayerEngine (LibVLC wrapper), playlist, settings, single-instance pipe, .NET Framework compatibility
  Interop/     Win32 helpers and the native video surface VLC renders into
  Views/       MainWindow (window modes), OverlayWindow, PlayerView (YouTube-style UI), UrlDialog
  Themes/      Icons and control styles
installer/     Inno Setup script (associations.iss is generated by build.ps1)
release/       The installers for every edition and their SHA-256 checksums
tools/         App icon generator
```

Settings, resume positions and `error.log` are stored in `%APPDATA%\VibePlayer`.
See `THIRD-PARTY-NOTICES.txt` for LibVLC (LGPL) and other licenses.
