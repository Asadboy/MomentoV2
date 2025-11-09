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
    
    private let supabaseManager = SupabaseManager.shared
    private let maxRetries = 3
    private let queueFileName = "upload_queue.json"
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadQueue()
        setupNetworkMonitoring()
    }
    
    // MARK: - Queue Management
    
    /// Add a photo to the upload queue
    func queuePhoto(image: UIImage, eventId: UUID) throws -> QueuedPhoto {
        // Save image to local storage
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
        
        // Try to upload immediately if online
        Task {
            await processQueue()
        }
        
        return queuedPhoto
    }
    
    /// Process all pending photos in the queue
    func processQueue() async {
        guard !isUploading else { return }
        
        await MainActor.run {
            isUploading = true
        }
        
        let pendingPhotos = queue.filter { $0.status == .pending || $0.status == .failed }
        
        for photo in pendingPhotos {
            await uploadQueuedPhoto(photo)
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
        
        // Check retry limit
        if photo.retryCount >= maxRetries {
            await MainActor.run {
                queue[index].status = .failed
                queue[index].errorMessage = "Max retries exceeded"
                saveQueue()
            }
            return
        }
        
        // Update status to uploading
        await MainActor.run {
            queue[index].status = .uploading
            queue[index].lastAttemptAt = Date()
            saveQueue()
        }
        
        do {
            // Load image from disk
            guard let imageData = try? Data(contentsOf: photo.localFileURL),
                  let image = UIImage(data: imageData),
                  let jpegData = image.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "OfflineSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load image"])
            }
            
            // Upload to Supabase
            _ = try await supabaseManager.uploadPhoto(image: jpegData, eventId: photo.eventId)
            
            // Mark as completed
            await MainActor.run {
                if let updatedIndex = queue.firstIndex(where: { $0.id == photo.id }) {
                    queue[updatedIndex].status = .completed
                    saveQueue()
                }
            }
            
            // Delete local file
            try? FileManager.default.removeItem(at: photo.localFileURL)
            
            print("✅ Photo uploaded successfully: \(photo.id)")
            
        } catch {
            // Mark as failed, increment retry count
            await MainActor.run {
                if let updatedIndex = queue.firstIndex(where: { $0.id == photo.id }) {
                    queue[updatedIndex].status = .failed
                    queue[updatedIndex].retryCount += 1
                    queue[updatedIndex].errorMessage = error.localizedDescription
                    saveQueue()
                }
            }
            
            print("❌ Failed to upload photo: \(error.localizedDescription)")
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
    
    /// Save image to local storage
    private func saveImageToLocal(_ image: UIImage, photoId: UUID) throws -> URL {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "OfflineSyncManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG"])
        }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let queueDirectory = documentsDirectory.appendingPathComponent("upload_queue", isDirectory: true)
        
        // Create queue directory if it doesn't exist
        try? FileManager.default.createDirectory(at: queueDirectory, withIntermediateDirectories: true)
        
        let fileURL = queueDirectory.appendingPathComponent("\(photoId.uuidString).jpg")
        try imageData.write(to: fileURL)
        
        return fileURL
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
            queue = try decoder.decode([QueuedPhoto].self, from: data)
            
            // Reset uploading status to pending (in case app crashed during upload)
            for index in queue.indices where queue[index].status == .uploading {
                queue[index].status = .pending
            }
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
}

