# Phosphene

Video wallpapers for macOS Tahoe.

Play your own video files as the desktop and lock-screen wallpaper. Phosphene hooks into the native wallpaper picker so your videos appear right next to Apple's built-in Aerials in **System Settings > Wallpaper**. Built on the same private `WallpaperExtensionKit` framework Apple uses internally — playback is out-of-process, survives app quits, and respects the OS lock screen / idle / sleep lifecycle.

> This is a private framework. Apple could break it at any major release. Phosphene tracks macOS 26 (Tahoe).

## Build

```
make
make install
```

Requires Apple Silicon and Command Line Tools (`xcode-select --install`). Optional: `brew install ffmpeg` for automatic VP9/AV1 transcoding on import.

`make install` copies the app to `/Applications` and deploys the extension to `~/Library/ExtensionKit/Extensions/`.

## Usage

1. Launch Phosphene. Add videos with the **+** button.
2. Open **System Settings > Wallpaper**. Your videos appear under their own collection.
3. Pick one. macOS handles assignment — the extension provides the frames.

Settings are in **Phosphene > Settings** (Cmd+,): pause when occluded, lock-screen-only mode, launch at login.

## What this fork changed

This is a ground-up rewrite of the parts that mattered. The original was broken in ways that made it non-functional for most users.

**Fixed the XPC pipeline.** The original extension never created `_EXRunningExtension.internalListener`, so `extensiond` couldn't broker connections and the wallpaper silently failed to load. We reverse-engineered ExtensionKit's bootstrap and implemented a two-phase `EXExtensionMain` sequence that correctly initializes the singleton. This is the fix that makes Phosphene actually work.

**Fixed black wallpaper.** VP9/AV1 videos (most YouTube downloads) can't be decoded in a sandboxed AVFoundation context. The original showed black. We transcode to H.264 via ffmpeg automatically on import.

**Fixed missing thumbnails.** `AVAssetImageGenerator` fails on non-H.264 sources. The original skipped those entries entirely — nothing appeared in the picker. We generate gradient placeholders as a fallback.

**Replaced the build system.** One `Makefile` compiles everything with `swiftc` from Command Line Tools. Generates plists, entitlements, code-signs, installs. No IDE, no project files, no asset catalogs.

**Replaced the app UI.** Was a menu bar accessory. Now a normal windowed app with a library, inspector, toolbar, and a Settings pane.

**Rewrote the extension entry point.** New `main.swift` with reentry detection, vtable patching for `shouldAcceptNewConnection`, init swizzling to capture the `_EXRunningExtension` singleton, and extension identity pre-seeding. None of this existed before.

**Rebranded.** `glass.kagerou.phosphene` is gone. Bundle ID is `dev.phosphene`. Existing video libraries are migrated automatically on first launch.

## Features

- **Any video format.** Import MP4, MOV, whatever. Non-H.264/HEVC codecs are transcoded automatically via ffmpeg.
- **Gapless looping.** PTS/DTS offset across loop boundaries — no flush, no stutter.
- **Multi-display + per-Space.** Different wallpapers per screen, persisted by macOS.
- **Power-aware.** Graduated playback policy based on thermals, battery, AC/battery, presentation mode.
- **Lock-screen ramp.** Cubic ease in/out when transitioning between desktop and lock screen.
- **Occlusion detection.** Pauses when all displays are covered by windows.
- **Adaptive variants.** Pre-render lower-res/fps variants; renderer picks the cheapest one the current policy allows.

## Architecture

```
Phosphene.app                         PhospheneExtension.appex
(windowed UI)                         (hosted by WallpaperAgent)

 Library management        Darwin      XPC handler
 Auto-transcoding       ──notif──>     AVSampleBufferDisplayLayer
 Optimization (HEVC)                   Power / thermal monitor
 Preferences                           Snapshot generator

              Shared container
              ~/Library/Containers/dev.phosphene.extension/Data/Documents
              videos/ + metadata + prefs + state
```

The **app** manages the video library, transcodes on import, writes preferences, and signals changes via Darwin notifications.

The **extension** runs inside `WallpaperAgent`. It loads `WallpaperExtensionKit` via `dlopen`, bootstraps the XPC listener with the two-phase approach, and renders frames into a remote `CAContext` using `AVSampleBufferDisplayLayer` (not `AVPlayerLayer`, which silently fails in remote contexts). One `AVAssetReader` per loop, preloaded next reader, monotonic PTS offset for seamless looping.

`PlaybackPolicy` collapses thermals + battery + presentation mode + user pause + occlusion into `full / reduced / minimal / paused`. Applied on every state change.

## XPC Bootstrap

The `com.apple.wallpaper` extension point needs `_EXRunningExtension.internalListener` before `extensiond` will mediate connections. `AppExtension.main()` sets `_appExtension` but handles `_start()` reentry internally and never exposes the listener to third-party code.

Two-phase fix in `main.swift`:

1. `PhospheneWallpaper.main()` runs `AppExtension.main()` which calls `EXExtensionMain` and `_start()`. Sets `_appExtension` on the singleton. Returns.
2. Call `EXExtensionMain` directly. `_start()` reenters our C main — detected by `ext_main_already_called()` — returns immediately. `_start()` continues with `_appExtension` set, creates `internalListener`, enters its run loop. Never returns.

## License

[MIT](LICENSE).
