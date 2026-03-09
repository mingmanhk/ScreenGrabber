//
//  ThumbnailCache.swift
//  ScreenGrabber
//
//  Shared thumbnail cache using NSCache + CGImageSource for fast,
//  memory-efficient thumbnail generation without loading full images.
//

import SwiftUI
import AppKit
import CoreGraphics
import ImageIO

// MARK: - ThumbnailCache

/// Thread-safe shared thumbnail cache.
/// Uses CGImageSourceCreateThumbnailAtIndex for fast, low-memory thumbnail generation.
/// NSCache automatically evicts entries under memory pressure.
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 150 * 1024 * 1024 // 150 MB
    }

    /// Returns a cached thumbnail synchronously, or nil if not yet loaded.
    func thumbnail(for url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Evicts a specific entry (e.g. after the file is deleted or changed).
    func invalidate(url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    /// Evicts all cached thumbnails.
    func invalidateAll() {
        cache.removeAllObjects()
    }

    // MARK: - Async Load

    /// Loads and caches a thumbnail asynchronously.
    /// Uses CGImageSource for memory-efficient decoding — the full image is never loaded into RAM.
    /// Calling this when the result is already cached returns immediately.
    @discardableResult
    func load(url: URL, maxPixelSize: Int = 400) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }

                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: false
                ]

                guard
                    let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                    let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
                else {
                    continuation.resume(returning: nil)
                    return
                }

                let image = NSImage(cgImage: cgImage, size: .zero)
                let cost = cgImage.width * cgImage.height * 4

                DispatchQueue.main.async {
                    self.cache.setObject(image, forKey: url as NSURL, cost: cost)
                }
                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - AsyncThumbnail View

/// Drop-in SwiftUI view that loads a thumbnail from the cache asynchronously.
/// Shows a ProgressView while loading and an icon placeholder on failure.
struct AsyncThumbnail: View {
    let url: URL
    var maxPixelSize: Int = 400
    var contentMode: ContentMode = .fill

    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity.animation(.easeIn(duration: 0.15)))
            } else if failed {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
            }
        }
        .task(id: url) {
            image = ThumbnailCache.shared.thumbnail(for: url)
            guard image == nil else { return }
            let loaded = await ThumbnailCache.shared.load(url: url, maxPixelSize: maxPixelSize)
            if loaded == nil { failed = true }
            image = loaded
        }
    }
}
