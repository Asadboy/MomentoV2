//
//  PhotoStorageManager.swift
//  Momento
//
//  Created by Cursor on 09/11/2025.
//
//  Responsible for writing captured photos and metadata to the caches directory.
//

import Foundation
import UIKit

enum PhotoStorageError: Error {
    case cacheDirectoryUnavailable
    case encodingFailed
    case writeFailed
    case metadataMissing
}

/// Handles saving and loading photos within the local caches directory
final class PhotoStorageManager {
    static let shared = PhotoStorageManager()
    
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Public API
    
    /// Saves a photo and its metadata to disk
    func save(image: UIImage, for event: Event, capturedBy: String? = nil) throws -> EventPhoto {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw PhotoStorageError.encodingFailed
        }
        
        let cacheDirectory = try baseCacheDirectory()
        let eventDirectory = try makeEventDirectory(at: cacheDirectory, eventID: event.id)
        
        let photoID = UUID().uuidString
        let photoURL = eventDirectory.appendingPathComponent("\(photoID).jpg", isDirectory: false)
        let metadataURL = eventDirectory.appendingPathComponent("\(photoID).json", isDirectory: false)
        let capturedAt = Date()
        
        do {
            try imageData.write(to: photoURL, options: .atomic)
        } catch {
            throw PhotoStorageError.writeFailed
        }
        
        let metadata = PhotoMetadata(
            photoID: photoID,
            eventID: event.id,
            capturedAt: capturedAt,
            capturedBy: capturedBy,
            isRevealed: false
        )
        
        let metadataData = try encoder.encode(metadata)
        do {
            try metadataData.write(to: metadataURL, options: .atomic)
        } catch {
            throw PhotoStorageError.writeFailed
        }
        
        return EventPhoto(
            id: photoID,
            eventID: event.id,
            fileURL: photoURL,
            capturedAt: capturedAt,
            isRevealed: false,
            capturedBy: capturedBy,
            image: image
        )
    }
    
    /// Loads the metadata JSON for a saved photo
    func metadata(for photo: EventPhoto) throws -> PhotoMetadata {
        let metadataURL = photo.fileURL.deletingPathExtension().appendingPathExtension("json")
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            throw PhotoStorageError.metadataMissing
        }
        
        let data = try Data(contentsOf: metadataURL)
        return try decoder.decode(PhotoMetadata.self, from: data)
    }
    
    /// Updates the reveal status and persists it to disk
    func updateRevealStatus(for photo: EventPhoto, isRevealed: Bool) throws {
        var metadata = try metadata(for: photo)
        metadata.isRevealed = isRevealed
        let metadataURL = photo.fileURL.deletingPathExtension().appendingPathExtension("json")
        let data = try encoder.encode(metadata)
        try data.write(to: metadataURL, options: .atomic)
    }
    
    /// Loads an image from disk for a given photo reference
    func loadImage(for photo: EventPhoto) -> UIImage? {
        guard fileManager.fileExists(atPath: photo.fileURL.path) else {
            return nil
        }
        
        guard let data = try? Data(contentsOf: photo.fileURL) else {
            return nil
        }
        
        return UIImage(data: data)
    }
    
    /// Removes an entire event directory (used for cleanup)
    func removeEventDirectory(eventID: String) throws {
        let cacheDirectory = try baseCacheDirectory()
        let eventDirectory = cacheDirectory.appendingPathComponent("momento_\(eventID)", isDirectory: true)
        guard fileManager.fileExists(atPath: eventDirectory.path) else {
            return
        }
        try fileManager.removeItem(at: eventDirectory)
    }
    
    // MARK: - Helpers
    
    private func baseCacheDirectory() throws -> URL {
        guard let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw PhotoStorageError.cacheDirectoryUnavailable
        }
        return cacheDirectory
    }
    
    private func makeEventDirectory(at base: URL, eventID: String) throws -> URL {
        let eventDirectory = base.appendingPathComponent("momento_\(eventID)", isDirectory: true)
        if !fileManager.fileExists(atPath: eventDirectory.path) {
            try fileManager.createDirectory(at: eventDirectory, withIntermediateDirectories: true)
        }
        return eventDirectory
    }
}

