//
//  OfflineSyncManager.swift
//  Momento
//
//  Manages offline photo queue and background sync
//

import Foundation
import UIKit
import Combine
import Network

/// Status of a queued photo upload
enum UploadStatus: String, Codable {
    case pending
    case uploading
    case completed
    case failed
}

/// Represents a photo waiting to be uploaded
struct QueuedPhoto: Codable, Identifiable {
    let id: UUID
    let eventId: UUID
    let localFileURL: URL
    var status: UploadStatus
    var retryCount: Int
    let queuedAt: Date
    var lastAttemptAt: Date?
    var errorMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case localFileURL = "local_file_url"
        case status
        case retryCount = "retry_count"
        case queuedAt = "queued_at"
        case lastAttemptAt = "last_attempt_at"
        case errorMessage = "error_message"
    }
}

/// Manages offline photo uploads with automatic retry and background sync
class OfflineSyncManager: ObservableObject {
    static let shared = OfflineSyncManager()
    
    @Published var queue: [QueuedPhoto] = []
    @Published var isUploading = false
    @Published var activeUploads = 0
    /// Number of queue entries dropped at the last `loadQueue` because their
    /// local file was missing. Surfaced once at cold launch via a dismissible
    /// banner so users know a shot was lost rather than just silently gone.
    /// Reset to 0 when acknowledged.
    @Published var staleEntriesAtLaunch: Int = 0
    
    private let supabaseManager = SupabaseManager.shared
    private let filmFilter = BethanReynoldsFilter()  // Film filter
    private let maxRetries = 3
    private let maxConcurrentUploads = 3  // Upload 3 photos at once
    private let queueFileName = "upload_queue.json"

    private var cancellables = Set<AnyCancellable>()

    /// Cooldown for `retryFailedUploads` so a user mashing the banner's
    /// Retry button can't hammer the server. 15s is fast enough to be
    /// responsive, slow enough to prevent a thumb-mash storm.
    private let retryCooldown: TimeInterval = 15
    private var lastRetryAt: Date?

    /// Network path monitor — fires when connectivity transitions from
    /// unavailable to available so we can auto-retry without the user
    /// having to lift a finger. Created once at init; never stopped.
    private let pathMonitor = NWPathMonitor()
    private var lastPathStatus: NWPath.Status = .satisfied

    /// Safe accessor for the documents directory. Returns nil on the
    /// (vanishingly rare) iOS case where it's unavailable — fatalError
    /// in a singleton init/getter is a worse failure mode than a
    /// disabled upload queue (review H19).
    private var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    /// Same accessor with the queue subdirectory appended, plus an
    /// `isExcludedFromBackup` flag applied. Without the flag the queue
    /// would sync to iCloud — wasted bandwidth + storage for the user.
    private var queueDirectory: URL? {
        guard let documentsDirectory else { return nil }
        let dir = documentsDirectory.appendingPathComponent("upload_queue", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Mark the directory non-backed-up. Best-effort: iOS quietly
        // ignores the request if the directory doesn't exist yet, hence
        // the create-then-set order.
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableDir = dir
        try? mutableDir.setResourceValues(values)

        return mutableDir
    }

    private init() {
        loadQueue()
        setupNetworkMonitoring()
    }
    
    // MARK: - Queue Management
    
    /// Add a photo to the upload queue and start uploading immediately
    func queuePhoto(image: UIImage, eventId: UUID) throws -> QueuedPhoto {
        // Save image to local storage (compressed & resized)
        let photoId = UUID()
        let fileURL = try saveImageToLocal(image, photoId: photoId)
        
        let queuedPhoto = QueuedPhoto(
            id: photoId,
            eventId: eventId,
            localFileURL: fileURL,
            status: .pending,
            retryCount: 0,
            queuedAt: Date()
        )
        
        queue.append(queuedPhoto)
        saveQueue()

        // Fire-and-forget: Upload THIS photo immediately (don't wait for queue)
        Task.detached(priority: .userInitiated) {
            await self.uploadQueuedPhoto(queuedPhoto)
            await MainActor.run {
                self.cleanupCompletedUploads()
            }
        }
        
        return queuedPhoto
    }
    
    /// Process all pending photos in the queue (parallel uploads)
    func processQueue() async {
        let pendingPhotos = queue.filter { $0.status == .pending || $0.status == .failed }
        
        if pendingPhotos.isEmpty {
            return
        }
        
        debugLog("📤 Processing \(pendingPhotos.count) pending photo(s) with \(maxConcurrentUploads) concurrent uploads...")
        
        await MainActor.run {
            isUploading = true
        }
        
        // Upload in parallel batches
        await withTaskGroup(of: Void.self) { group in
            var activeCount = 0
            
            for photo in pendingPhotos {
                // Wait if we have too many active uploads
                if activeCount >= maxConcurrentUploads {
                    await group.next()
                    activeCount -= 1
                }
                
                activeCount += 1
                group.addTask {
                    await self.uploadQueuedPhoto(photo)
                }
            }
            
            // Wait for all remaining uploads
            await group.waitForAll()
        }
        
        await MainActor.run {
            isUploading = false
        }
        
        // Remove completed uploads
        cleanupCompletedUploads()
    }
    
    /// Atomically transitions a queued photo pending/failed -> uploading.
    /// Runs on the MainActor, which is the single serialization domain for
    /// all queue mutations, so a photo can be claimed for upload exactly
    /// once even when the immediate detached upload, processQueue, and
    /// retryFailedUploads race. Returns false if the photo is gone, already
    /// uploading/completed, or out of retries.
    @MainActor
    private func claimForUpload(_ photoId: UUID) -> Bool {
        guard let idx = queue.firstIndex(where: { $0.id == photoId }) else { return false }
        let status = queue[idx].status
        guard status == .pending || status == .failed else { return false }
        guard queue[idx].retryCount < maxRetries else { return false }
        queue[idx].status = .uploading
        queue[idx].lastAttemptAt = Date()
        activeUploads += 1
        saveQueue()
        return true
    }

    /// Upload a specific queued photo
    private func uploadQueuedPhoto(_ photo: QueuedPhoto) async {
        // Check retry limit
        if photo.retryCount >= maxRetries {
            await MainActor.run {
                if let idx = queue.firstIndex(where: { $0.id == photo.id }) {
                    queue[idx].status = .failed
                    queue[idx].errorMessage = "Max retries exceeded"
                    saveQueue()
                }
            }
            AnalyticsManager.shared.trackError(
                kind: "upload_failed_max_retries",
                context: [
                    "event_id": photo.eventId.uuidString,
                    "retry_count": photo.retryCount
                ]
            )
            return
        }

        // Check server-side photo limit before uploading
        if let userId = supabaseManager.currentUser?.id {
            do {
                let count = try await supabaseManager.getPhotoCount(
                    eventId: photo.eventId,
                    userId: userId
                )
                if count >= PhotoLimitConfig.defaultPhotoLimit {
                    // Distinguish a genuine over-limit from a retry of a shot
                    // that already uploaded (kill/double-fire). The latter
                    // must not be reported as a failure or have its local
                    // file destroyed. Three-way:
                    //   exists == true  -> already uploaded: mark completed
                    //   exists == false -> genuine over-limit: fail + delete
                    //   exists == nil   -> check errored: retryable, keep file
                    let existsResult = try? await supabaseManager.photoExists(clientUploadId: photo.id)
                    if existsResult == true {
                        debugLog("✅ Photo \(photo.id.uuidString.prefix(8)) already uploaded — marking complete (idempotent retry)")
                        await MainActor.run {
                            if let idx = queue.firstIndex(where: { $0.id == photo.id }) {
                                queue[idx].status = .completed
                                saveQueue()
                            }
                        }
                        try? FileManager.default.removeItem(at: photo.localFileURL)
                        return
                    }
                    if existsResult == nil {
                        // Couldn't verify whether this shot already uploaded
                        // (network/transient). Do NOT delete the file and do
                        // NOT cap retries — let it retry; the server trigger
                        // fix + upsert-ignore will no-op a true duplicate.
                        debugLog("⚠️ Could not verify upload for \(photo.id.uuidString.prefix(8)) at limit — will retry")
                        await MainActor.run {
                            if let idx = queue.firstIndex(where: { $0.id == photo.id }) {
                                queue[idx].status = .failed
                                queue[idx].errorMessage = "Couldn’t verify upload — will retry"
                                saveQueue()
                            }
                        }
                        return
                    }
                    debugLog("📷 Photo limit reached for event \(photo.eventId.uuidString.prefix(8)), dropping queued photo")
                    await MainActor.run {
                        if let idx = queue.firstIndex(where: { $0.id == photo.id }) {
                            queue[idx].status = .failed
                            queue[idx].errorMessage = "Photo limit reached — this photo was not uploaded"
                            saveQueue()
                        }
                    }
                    try? FileManager.default.removeItem(at: photo.localFileURL)
                    return
                }
            } catch {
                debugLog("⚠️ Could not check photo limit, proceeding with upload: \(error)")
            }
        }

        // Atomically claim this photo for upload. Exactly one caller wins.
        let claimed = await claimForUpload(photo.id)
        guard claimed else {
            debugLog("⏭️ Upload skipped — already claimed/ineligible: \(photo.id.uuidString.prefix(8))")
            return
        }

        do {
            // Load already-compressed image data directly
            guard let imageData = try? Data(contentsOf: photo.localFileURL) else {
                throw NSError(domain: "OfflineSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
            }
            
            // Upload to Supabase (already compressed, don't re-compress)
            _ = try await supabaseManager.uploadPhoto(image: imageData, eventId: photo.eventId, clientUploadId: photo.id)
            
            // Mark as completed
            await MainActor.run {
                if let updatedIndex = queue.firstIndex(where: { $0.id == photo.id }) {
                    queue[updatedIndex].status = .completed
                    activeUploads = max(0, activeUploads - 1)
                    saveQueue()
                }
            }
            
            // Delete local file
            try? FileManager.default.removeItem(at: photo.localFileURL)
            
            debugLog("✅ Photo \(photo.id.uuidString.prefix(8)) uploaded!")
            
        } catch {
            let isLimit = isPhotoLimitError(error)
            await MainActor.run {
                if let updatedIndex = queue.firstIndex(where: { $0.id == photo.id }) {
                    queue[updatedIndex].status = .failed
                    if isLimit {
                        // Terminal failure — retrying won't help, and we
                        // want the user-facing message to be honest about
                        // why. Cap retryCount so auto-retry skips this row.
                        queue[updatedIndex].retryCount = maxRetries
                        queue[updatedIndex].errorMessage = "Photo limit reached — this shot was not uploaded"
                    } else {
                        queue[updatedIndex].retryCount += 1
                        queue[updatedIndex].errorMessage = error.localizedDescription
                    }
                    activeUploads = max(0, activeUploads - 1)
                    saveQueue()
                }
            }

            if isLimit {
                // No point keeping the bytes around — server will never
                // accept them. Mirrors the pre-upload limit-check path.
                try? FileManager.default.removeItem(at: photo.localFileURL)
                debugLog("❌ Upload rejected: server-side photo limit reached")
            } else {
                debugLog("❌ Upload failed: \(error.localizedDescription)")
            }
        }
    }

    /// Remove completed uploads from queue
    private func cleanupCompletedUploads() {
        DispatchQueue.main.async {
            self.queue.removeAll { $0.status == .completed }
            self.saveQueue()
        }
    }
    
    /// Retry failed uploads. Rate-limited via `retryCooldown` so repeated
    /// taps on the failure banner can't hammer the server when the underlying
    /// problem is server-side (Supabase down, network struggling).
    func retryFailedUploads() {
        if let last = lastRetryAt, Date().timeIntervalSince(last) < retryCooldown {
            debugLog("⏳ Retry within \(Int(retryCooldown))s cooldown — ignoring")
            return
        }
        lastRetryAt = Date()

        Task {
            for index in queue.indices where queue[index].status == .failed {
                queue[index].status = .pending
                queue[index].retryCount = 0
            }
            saveQueue()

            await processQueue()
        }
    }
    
    // MARK: - Local Storage
    
    /// Save image to local storage (filtered, resized, compressed for fast upload)
    private func saveImageToLocal(_ image: UIImage, photoId: UUID) throws -> URL {
        // Step 1: Resize image to max 1200px on longest side
        let resizedImage = resizeImage(image, maxDimension: 1200)
        
        // Step 2: Apply film filter
        let filteredImage = filmFilter.apply(to: resizedImage)
        
        // Step 3: Compress to 0.5 quality (~150-300KB)
        guard let imageData = filteredImage.jpegData(compressionQuality: 0.5) else {
            throw NSError(domain: "OfflineSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }
        
        guard let queueDirectory = queueDirectory else {
            throw NSError(domain: "OfflineSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Documents directory unavailable"])
        }

        let fileURL = queueDirectory.appendingPathComponent("\(photoId.uuidString).jpg")
        try imageData.write(to: fileURL)

        debugLog("🎞️ Photo processed: \(imageData.count / 1024)KB with Kodak Gold filter")

        return fileURL
    }
    
    /// Resize image to max dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        
        // If already small enough, return original
        if maxSide <= maxDimension {
            return image
        }
        
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Save queue to disk
    private func saveQueue() {
        guard let documentsDirectory = documentsDirectory else { return }
        let queueFileURL = documentsDirectory.appendingPathComponent(queueFileName)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(queue)
            try data.write(to: queueFileURL)
        } catch {
            debugLog("Failed to save queue: \(error)")
        }
    }

    /// Load queue from disk
    private func loadQueue() {
        guard let documentsDirectory = documentsDirectory else { return }
        let queueFileURL = documentsDirectory.appendingPathComponent(queueFileName)
        
        guard FileManager.default.fileExists(atPath: queueFileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: queueFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            var loadedQueue = try decoder.decode([QueuedPhoto].self, from: data)
            
            // Reset uploading status to pending (in case app crashed during upload)
            for index in loadedQueue.indices where loadedQueue[index].status == .uploading {
                loadedQueue[index].status = .pending
            }
            
            // Remove items where local file no longer exists (stale queue entries)
            let validQueue = loadedQueue.filter { photo in
                let exists = FileManager.default.fileExists(atPath: photo.localFileURL.path)
                if !exists {
                    debugLog("🗑️ Removing stale queue entry (file missing): \(photo.id)")
                }
                return exists
            }
            
            let dropped = loadedQueue.count - validQueue.count
            if dropped > 0 {
                debugLog("🧹 Cleaned up \(dropped) stale queue entries")
                staleEntriesAtLaunch = dropped
                AnalyticsManager.shared.trackError(
                    kind: "stale_queue_entries_dropped",
                    context: ["count": dropped]
                )
            }

            queue = validQueue
            saveQueue() // Save the cleaned queue
        } catch {
            debugLog("Failed to load queue: \(error)")
        }
    }
    
    // MARK: - Network Monitoring
    
    /// Setup network monitoring to auto-sync when online
    private func setupNetworkMonitoring() {
        // Monitor authentication changes - sync when user logs in
        supabaseManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                guard let self = self else { return }
                if isAuthenticated {
                    Task {
                        await self.processQueue()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Process queue when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                debugLog("📱 App became active - processing upload queue...")
                debugLog("   Pending: \(self.pendingCount), Failed: \(self.failedCount)")
                Task {
                    await self.processQueue()
                }
            }
            .store(in: &cancellables)
        
        // Also process when entering foreground (catches more cases)
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.processQueue()
                }
            }
            .store(in: &cancellables)

        // Auto-retry when network connectivity is restored. Fires once on
        // each unsatisfied→satisfied transition so a flaky signal doesn't
        // trigger a barrage of retry attempts. Combined with the
        // `retryCooldown` above, this keeps recovery friendly even on a
        // train commute. Path-handler fires off the main thread; marshal
        // back via Task.
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let wasOffline = self.lastPathStatus != .satisfied
            self.lastPathStatus = path.status
            guard wasOffline, path.status == .satisfied else { return }
            debugLog("📶 Network restored — processing upload queue")
            Task { await self.processQueue() }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }
    
    // MARK: - Queue Statistics
    
    var pendingCount: Int {
        queue.filter { $0.status == .pending || $0.status == .uploading }.count
    }
    
    var failedCount: Int {
        queue.filter { $0.status == .failed }.count
    }
    
    var completedCount: Int {
        queue.filter { $0.status == .completed }.count
    }

    /// Dismiss the stale-entries banner. Called from the banner's close
    /// button — the count is informational and never reappears for the
    /// same launch.
    func acknowledgeStaleEntries() {
        staleEntriesAtLaunch = 0
    }

    /// Clear the entire upload queue (for debugging/testing)
    func clearQueue() {
        debugLog("🗑️ Clearing entire upload queue (\(queue.count) items)")
        queue.removeAll()
        saveQueue()

        // Also delete the queue directory
        if let documentsDirectory = documentsDirectory {
            let dir = documentsDirectory.appendingPathComponent("upload_queue", isDirectory: true)
            try? FileManager.default.removeItem(at: dir)
        }

        debugLog("✅ Upload queue cleared")
    }
}

