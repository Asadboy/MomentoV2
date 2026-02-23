//
//  PhotoLimitConfig.swift
//  Momento
//
//  Photo limit configuration — easy to swap to host-configurable later
//

import Foundation

enum PhotoLimitConfig {
    /// Default photo limit per person per event.
    /// Future: replace with event.photoLimit from server.
    static let defaultPhotoLimit = 12
}
