//
//  PhotoData.swift
//  Momento
//
//  Simplified photo model used by reveal / liked-gallery UI. Distinct from
//  `PhotoModel` which is the wire DTO for the photos table.
//

import Foundation

/// Simplified photo data for reveal UI.
struct PhotoData: Identifiable {
    let id: String
    let url: URL?
    let capturedAt: Date
    let photographerName: String?
}
