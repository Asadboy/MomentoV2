//
//  ImageCacheManager.swift
//  Momento
//
//  Two-tier image caching: memory (NSCache) + bounded disk cache.
//  Reduces bandwidth by preventing re-downloads on scroll.
//

import UIKit
import CryptoKit

class ImageCacheManager {
    static let shared = ImageCacheManager()

    // MARK: - Memory Cache
    private let memoryCache = NSCache<NSString, UIImage>()

    // MARK: - Disk Cache
    private let diskCacheLimit = 100 * 1024 * 1024 // 100MB

    /// Optional because we want the manager to degrade to memory-only if
    /// the caches directory is genuinely unavailable (vanishingly rare on
    /// iOS but a fatalError in a singleton init is a worse failure mode
    /// than a degraded cache).
    private let cacheDirectory: URL?

    private init() {
        // Set up disk cache directory.
        let fileManager = FileManager.default
        if let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let dir = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            cacheDirectory = dir
        } else {
            // Closes review H19 — fatalError in a singleton init was a
            // launch-blocker pattern. Degrade to memory-only.
            debugLog("⚠️ ImageCache: caches directory unavailable; running memory-only")
            cacheDirectory = nil
        }

        // Configure memory cache
        memoryCache.countLimit = 30 // Max 30 images in memory
        memoryCache.totalCostLimit = 30 * 1024 * 1024 // ~30MB
    }

    // MARK: - Public API

    /// Get image from cache or download
    func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)

        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // 2. Check disk cache
        if let diskCached = loadFromDisk(key: key) {
            memoryCache.setObject(diskCached, forKey: key as NSString)
            return diskCached
        }

        // 3. Download and cache
        guard let image = await downloadImage(url: url) else { return nil }

        // Save to both caches
        memoryCache.setObject(image, forKey: key as NSString)
        saveToDisk(image: image, key: key)

        return image
    }

    /// Get image from cache (by stable ID) or download from URL
    /// Use this when the URL changes (e.g. signed URLs) but the content is the same.
    func image(for url: URL, cacheId: String) async -> UIImage? {
        let key = "id_\(cacheId)"

        // 1. Check memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // 2. Check disk cache
        if let diskCached = loadFromDisk(key: key) {
            memoryCache.setObject(diskCached, forKey: key as NSString)
            return diskCached
        }

        // 3. Download and cache
        guard let image = await downloadImage(url: url) else { return nil }

        memoryCache.setObject(image, forKey: key as NSString)
        saveToDisk(image: image, key: key)

        return image
    }

    /// Clear all caches
    func clearAll() {
        memoryCache.removeAllObjects()
        guard let cacheDirectory else { return }
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Clear disk cache only (memory stays for current session)
    func clearDiskCache() {
        guard let cacheDirectory else { return }
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private Helpers

    /// Closes review H20.
    ///
    /// The previous implementation used `url.absoluteString.hashValue`,
    /// which Swift seeds randomly per process — so the same URL produced
    /// a different key on every cold launch. The disk cache was
    /// effectively empty on every cold start; every image re-downloaded.
    ///
    /// SHA-256 of the URL string is deterministic across launches.
    /// First 16 hex chars are unique enough for our cache scale
    /// (10⁻²⁰ collision odds at thousands of images).
    private func cacheKey(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let digest = SHA256.hash(data: data)
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        return "\(url.lastPathComponent)_\(hex.prefix(16))"
    }

    private func diskPath(for key: String) -> URL? {
        cacheDirectory?.appendingPathComponent(key)
    }

    private func loadFromDisk(key: String) -> UIImage? {
        guard let path = diskPath(for: key) else { return nil }
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(image: UIImage, key: String) {
        guard let path = diskPath(for: key) else { return }
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        // Check cache size before saving
        enforceDiskLimit()

        try? data.write(to: path)
    }

    private func downloadImage(url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            debugLog("❌ Failed to download image: \(error)")
            return nil
        }
    }

    private func enforceDiskLimit() {
        let fileManager = FileManager.default
        guard let cacheDirectory else { return }
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else { return }

        // Calculate total size
        var totalSize = 0
        var fileInfos: [(url: URL, size: Int, date: Date)] = []

        for file in files {
            guard let attrs = try? file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                  let size = attrs.fileSize,
                  let date = attrs.creationDate else { continue }
            totalSize += size
            fileInfos.append((file, size, date))
        }

        // If over limit, delete oldest files
        if totalSize > diskCacheLimit {
            let sorted = fileInfos.sorted { $0.date < $1.date }
            var freedSpace = 0

            for file in sorted {
                try? fileManager.removeItem(at: file.url)
                freedSpace += file.size
                if totalSize - freedSpace < diskCacheLimit { break }
            }
        }
    }
}
