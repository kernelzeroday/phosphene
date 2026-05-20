// Video file discovery backed by VideoLibrary.
//
// Provides backward-compatible `findVideoURL()` that returns the currently
// selected video (or first available), plus library-aware alternatives.

import AVFoundation
import ImageIO

/// Find the video URL for the currently selected wallpaper.
/// Falls back to the first video in the library, then bundle resources.
func findVideoURL() -> URL? {
    if let cached = WallpaperState.shared.cachedVideoURL {
        return cached
    }

    // Check if a specific video is selected
    if let selectedID = WallpaperState.shared.currentVideoID,
       let url = VideoLibrary.shared.videoURL(for: selectedID),
       FileManager.default.fileExists(atPath: url.path) {
        WallpaperState.shared.cachedVideoURL = url
        return url
    } else if WallpaperState.shared.currentVideoID != nil {
        // Selected video is gone — clear stale ID
        WallpaperState.shared.currentVideoID = nil
    }

    // Fall back to first video in library
    if let first = VideoLibrary.shared.entries.first {
        let url = VideoLibrary.shared.videoURL(for: first)
        if FileManager.default.fileExists(atPath: url.path) {
            WallpaperState.shared.cachedVideoURL = url
            WallpaperState.shared.currentVideoID = first.id
            return url
        }
    }

    // Last resort: bundle resource
    let videoExtensions = ["mp4", "mov", "m4v"]
    for ext in videoExtensions {
        if let url = Bundle.main.url(forResource: "wallpaper", withExtension: ext) {
            WallpaperState.shared.cachedVideoURL = url
            return url
        }
    }

    return nil
}

/// Generate a JPEG thumbnail from the video's first frame.
/// Used by SettingsProvider for the System Settings picker.
func generateThumbnail(from videoURL: URL) async -> URL? {
    let asset = AVURLAsset(url: videoURL)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 480, height: 270)

    let cgImage: CGImage
    do {
        cgImage = try await generator.image(at: .zero).image
    } catch {
        extensionLog("  Thumbnail generation failed: \(error)")
        return nil
    }

    let docsDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
    try? FileManager.default.createDirectory(at: docsDir, withIntermediateDirectories: true)
    let thumbnailURL = docsDir.appendingPathComponent("thumbnail.jpg")

    guard let dest = CGImageDestinationCreateWithURL(
        thumbnailURL as CFURL, "public.jpeg" as CFString, 1, nil,
    ) else {
        extensionLog("  Thumbnail: failed to create image destination")
        return nil
    }
    CGImageDestinationAddImage(dest, cgImage, [
        kCGImageDestinationLossyCompressionQuality: 0.85,
    ] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else {
        extensionLog("  Thumbnail: failed to finalize")
        return nil
    }

    extensionLog("  Thumbnail saved: \(thumbnailURL.path)")
    return thumbnailURL
}
