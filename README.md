# Phosphene

A video wallpaper engine for macOS Tahoe. No Xcode required.

Phosphene plays your own video files as the macOS desktop and lock-screen wallpaper. It plugs into the system's native wallpaper picker — videos appear alongside Apple's built-in Aerials in **System Settings → Wallpaper**. It is built on Apple's private `WallpaperExtensionKit` framework, the same one Apple's own Aerials use, so playback runs out-of-process, survives app quits, and integrates with the OS-level lock screen, idle, and sleep lifecycle.

> **Private framework.** Phosphene loads `WallpaperExtensionKit` via `dlopen` and uses runtime introspection to talk to its XPC types. Apple could change this at any major OS release. The project tracks macOS 26 (Tahoe).

## This Fork

This is a substantially rewritten fork. The original codebase had a broken XPC pipeline, required Xcode to build, hid behind a menu bar icon, couldn't handle common video codecs, and was littered with branding nobody asked for. Here's what changed:

### What we fixed

- **XPC bootstrap was completely broken.** The original extension never created `_EXRunningExtension.internalListener`, so `extensiond` couldn't mediate connections and the wallpaper silently failed. We reverse-engineered the ExtensionKit bootstrap sequence and implemented a two-phase `EXExtensionMain` approach that correctly initializes the singleton's internal listener. This is the core fix that makes Phosphene actually work.
- **Black wallpaper on most videos.** VP9 and AV1 codecs (common in YouTube downloads) can't be decoded by sandboxed AVFoundation. The original app just showed a black screen. We added automatic transcoding to H.264 via ffmpeg on import — the user never has to think about codecs.
- **Thumbnails failed silently.** When `AVAssetImageGenerator` couldn't extract a frame (common with non-H.264 sources), the wallpaper picker showed nothing. We added a gradient placeholder fallback so entries always appear in the picker.
- **`WallpaperSnapshotXPC` encoder bypass.** The system's snapshot encoder checks `type(of: coder) == NSXPCCoder.self` but the actual coder is `NSXPCEncoder` (a subclass). Without a runtime ISA swizzle, snapshots encode to nothing and you get a grey lock screen during transitions. This was present in the original but undocumented.

### What we rewrote

- **Build system.** Ripped out Xcode entirely. A single `Makefile` compiles both the app and extension using `swiftc` from Command Line Tools. `make && make install` — that's it. No xcodeproj, no asset catalogs, no build settings UI.
- **App architecture.** Converted from a menu bar accessory app to a normal windowed application. The menu bar icon was bad UI — it added clutter for no reason. Phosphene now launches as a regular app with a library window front and center, a toolbar, and a proper Settings pane (Cmd+,).
- **Extension entry point.** Completely new `main.swift` with reentry detection (`exit_catcher.c`), vtable patching for `shouldAcceptNewConnection`, init swizzling to capture the `_EXRunningExtension` singleton, and identity pre-seeding. None of this existed in the original.
- **Branding.** Removed all `glass.kagerou.phosphene` identifiers and replaced with `dev.phosphene`. Removed attribution links. Added automatic migration of video data from the old container path.

### What we added

- **Automatic codec transcoding.** Videos using VP9, AV1, or any non-H.264/HEVC codec are automatically transcoded to H.264 on import via ffmpeg. The original just failed.
- **Settings pane.** Playback options (Only on Lock Screen, Pause When Hidden) and general settings (Resume on Launch, Launch at Login) are now in a proper macOS Settings window instead of buried in a popover.
- **Container migration.** Existing video libraries from the old bundle ID are automatically copied to the new container on first launch.

## Features

- **Bring your own videos.** Import MP4, MOV, or any video file. Incompatible codecs are transcoded automatically.
- **Gapless looping.** Frame-accurate loops by offsetting PTS/DTS across loop boundaries — no flush, no stutter.
- **Multi-display + per-Space selections.** Different wallpapers per display, persisted by macOS.
- **Power-aware playback.** A graduated `PlaybackPolicy` reduces work or pauses based on thermal state, battery level, AC/battery, and presentation mode.
- **Smooth lock-screen ramp.** When *Only on Lock Screen* is enabled, the wallpaper eases in/out with a cubic curve as you lock and unlock.
- **Pause when occluded.** Detects when every display is fully covered by windows and pauses rendering.
- **Adaptive variants.** Optionally pre-render lower-resolution/fps variants; the renderer swaps to the cheapest one that satisfies the current policy at each loop boundary.

## Requirements

- **macOS Tahoe (26.0+)**
- **Apple Silicon** (`arm64-apple-macos26.0`)
- **Command Line Tools** (`xcode-select --install`) — Xcode is not needed
- **ffmpeg** (optional, for automatic transcoding of VP9/AV1 videos) — `brew install ffmpeg`

## Building

```sh
git clone https://github.com/kernelzeroday/phosphene
cd phosphene
make
make install
```

That's it. The Makefile compiles both targets with `swiftc`, generates Info.plists and entitlements, code-signs with an ad-hoc signature, copies the app to `/Applications`, and deploys the extension to `~/Library/ExtensionKit/Extensions/`.

To clean: `make clean`

### Using a video wallpaper

1. Launch Phosphene. Use the **+** button or drag videos into the library window.
2. Open **System Settings → Wallpaper**. Phosphene's videos appear under their own collection.
3. Pick a video. macOS handles the wallpaper assignment — Phosphene's extension provides the frames.

## Architecture

```
┌─────────────────────────┐         ┌──────────────────────────────┐
│  Phosphene.app          │         │  PhospheneExtension.appex     │
│  (windowed UI)          │         │  (host: WallpaperAgent)       │
│                         │         │                              │
│  • Library management   │  Darwin │  • XPC handler                │
│  • Auto-transcoding     │ ──────▶ │  • AVSampleBufferDisplayLayer │
│  • Optimization (HEVC)  │  notif. │  • Power / thermal monitor    │
│  • Preferences          │         │  • Snapshot generator         │
└─────────────────────────┘         └──────────────────────────────┘
                  │                              │
                  └──────────────┬───────────────┘
                                 ▼
                  Extension container
                  (~/Library/Containers/dev.phosphene.extension/Data/Documents)
                  • Video library + variants + metadata
                  • Prefs / state JSON files
```

**App** (`Phosphene/`) — SwiftUI windowed app. Manages the video library, transcodes incompatible codecs and optional variants, writes shared preferences, and posts Darwin notifications when the library changes.

**Extension** (`PhospheneExtension/`) — runs inside the system `WallpaperAgent` process. Loads `WallpaperExtensionKit.framework` at runtime, bootstraps via the two-phase `EXExtensionMain` approach, and renders frames into a remote `CAContext` via `AVSampleBufferDisplayLayer`. Receives XPC `acquire` / `update` / `invalidate` / `snapshot` calls from `WallpaperAgent`.

**`PlaybackPolicy`** collapses all inputs (thermal state, battery, presentation mode, user pause, occlusion) into one of `full / reduced / minimal / paused`. The renderer applies the policy on every state change.

**`VideoRenderer`** drives `AVSampleBufferDisplayLayer` manually instead of `AVPlayerLayer` (which silently fails inside a remote `CAContext`). One `AVAssetReader` for the current loop, a preloaded one for the next, and a monotonically increasing PTS offset across loops for glitch-free looping.

## XPC Bootstrap (the hard part)

The `com.apple.wallpaper` extension point requires `_EXRunningExtension.internalListener` to exist before `extensiond` will mediate XPC connections. The standard `AppExtension.main()` path sets `_appExtension` on the singleton but handles `_start()` reentry internally, never creating the internal listener for third-party extensions.

The fix is a two-phase bootstrap in `main.swift`:

1. **Phase 1:** `PhospheneWallpaper.main()` → `AppExtension.main()` → `EXExtensionMain` → `_start()`. Sets `_appExtension @72` on the singleton. `_start()` reenters but `AppExtension` handles it internally. Returns.
2. **Phase 2:** Call `EXExtensionMain` directly. `_start()` reenters our binary's C main — detected by `ext_main_already_called()` — returns. `_start()` continues with `_appExtension` already set, passes the type check, creates `internalListener @16`, enters its run loop. Never returns.

## License

[MIT](LICENSE).
