//
//  OfflineSyncManager.swift
//  Momento
//
//  Manages offline photo queue and background sync
//

import Foundation
import UIKit
import Combine

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
    
    private let supabaseManager = SupabaseManager.shared
    private let filmFilter = BethanReynoldsFilter()  // Film filter
    private let maxRetries = 3
    private let maxConcurrentUploads = 3  // Upload 3 photos at once
    private let queueFileName = "upload_queue.json"
    
    private var cancellables = Set<AnyCancellable>()
    
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

        // Track photo captured event
        AnalyticsManager.shared.track(.photoCaptured, properties: [
            "event_id": eventId.uuidString,
            "user_photo_count": queue.filter { $0.eventId == eventId }.count
        ])

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
            print("📭 No pending photos to upload")
            return
        }
        
        print("📤 Processing \(pendingPhotos.count) pending photo(s) with \(maxConcurrentUploads) concurrent uploads...")
        
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
    
    /// Upload a specific queued photo
    private func uploadQueuedPhoto(_ photo: QueuedPhoto) async {
        guard let index = queue.firstIndex(where: { $0.id == photo.id }) else {
            return
        }
        
        // Skip if already uploading or completed
        if queue[index].status == .uploading || queue[index].status == .completed {
            return
        }
        
        // Check retry limit
        if photo.retryCount >= maxRetries {
            await MainActor.run {
                if let idx = queue.firstIndex(where: { $0.id == photo.id }) {
                    queue[idx].status = .failed
                    queue[idx].errorMessage = "Max retries exceeded"
                    saveQueue()
                }
            }
            return
        }
        
        // Update status to uploading
        await MainActor.run {
            if let idx = queue.firstIndex(where: { $0.id == photo.id }) {
                queue[idx].status = .uploading
                queue[idx].lastAttemptAt = Date()
                activeUploads += 1
                saveQueue()
            }
        }
        
        do {
            // Load already-compressed image data directly
            guard let imageData = try? Data(contentsOf: photo.localFileURL) else {
                throw NSError(domain: "OfflineSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
            }
            
            // Upload to Supabase (already compressed, don't re-compress)
            _ = try await supabaseManager.uploadPhoto(image: imageData, eventId: photo.eventId)
            
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
            
            print("✅ Photo \(photo.id.uuidString.prefix(8)) uploaded!")
            
        } catch {
            // Mark as failed, increment retry count
            await MainActor.run {
                if let updatedIndex = queue.firstIndex(where: { $0.id == photo.id }) {
                    queue[updatedIndex].status = .failed
                    queue[updatedIndex].retryCount += 1
                    queue[updatedIndex].errorMessage = error.localizedDescription
                    activeUploads = max(0, activeUploads - 1)
                    saveQueue()
                }
            }
            
            print("❌ Upload failed: \(error.localizedDescription)")
        }
    }
    
    /// Remove completed uploads from queue
    private func cleanupCompletedUploads() {
        DispatchQueue.main.async {
            self.queue.removeAll { $0.status == .completed }
            self.saveQueue()
        }
    }
    
    /// Retry failed uploads
    func retryFailedUploads() {
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
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let queueDirectory = documentsDirectory.appendingPathComponent("upload_queue", isDirectory: true)
        
        // Create queue directory if it doesn't exist
        try? FileManager.default.createDirectory(at: queueDirectory, withIntermediateDirectories: true)
        
        let fileURL = queueDirectory.appendingPathComponent("\(photoId.uuidString).jpg")
        try imageData.write(to: fileURL)
        
        print("🎞️ Photo processed: \(imageData.count / 1024)KB with Kodak Gold filter")
        
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
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let queueFileURL = documentsDirectory.appendingPathComponent(queueFileName)
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(queue)
            try data.write(to: queueFileURL)
        } catch {
            print("Failed to save queue: \(error)")
        }
    }
    
    /// Load queue from disk
    private func loadQueue() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
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
                    print("🗑️ Removing stale queue entry (file missing): \(photo.id)")
                }
                return exists
            }
            
            if validQueue.count != loadedQueue.count {
                print("🧹 Cleaned up \(loadedQueue.count - validQueue.count) stale queue entries")
            }
            
            queue = validQueue
            saveQueue() // Save the cleaned queue
        } catch {
            print("Failed to load queue: \(error)")
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
                print("📱 App became active - processing upload queue...")
                print("   Pending: \(self.pendingCount), Failed: \(self.failedCount)")
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
    
    /// Clear the entire upload queue (for debugging/testing)
    func clearQueue() {
        print("🗑️ Clearing entire upload queue (\(queue.count) items)")
        queue.removeAll()
        saveQueue()
        
        // Also delete the queue directory
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let queueDirectory = documentsDirectory.appendingPathComponent("upload_queue", isDirectory: true)
        try? FileManager.default.removeItem(at: queueDirectory)
        
        print("✅ Upload queue cleared")
    }
}

