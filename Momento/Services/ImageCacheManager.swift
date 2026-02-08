//
//  ImageCacheManager.swift
//  Momento
//
//  Two-tier image caching: memory (NSCache) + bounded disk cache.
//  Reduces bandwidth by preventing re-downloads on scroll.
//

import UIKit

class ImageCacheManager {
    static let shared = ImageCacheManager()

    // MARK: - Memory Cache
    private let memoryCache = NSCache<NSString, UIImage>()

    // MARK: - Disk Cache
    private let diskCacheLimit = 100 * 1024 * 1024 // 100MB
    private let cacheDirectory: URL

    private init() {
        // Set up disk cache directory
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cacheDir.appendingPathComponent("ImageCache", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Configure memory cache
        memoryCache.countLimit = 50 // Max 50 images in memory
        memoryCache.totalCostLimit = 50 * 1024 * 1024 // ~50MB
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

    /// Clear all caches
    func clearAll() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    /// Clear disk cache only (memory stays for current session)
    func clearDiskCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Private Helpers

    private func cacheKey(for url: URL) -> String {
        // Use URL's last path component + hash for uniqueness
        let hash = url.absoluteString.hashValue
        return "\(url.lastPathComponent)_\(hash)"
    }

    private func diskPath(for key: String) -> URL {
        cacheDirectory.appendingPathComponent(key)
    }

    private func loadFromDisk(key: String) -> UIImage? {
        let path = diskPath(for: key)
        guard let data = try? Data(contentsOf: path) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(image: UIImage, key: String) {
        let path = diskPath(for: key)
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
