//
//  ProfileStats.swift
//  Momento
//
//  Profile screen aggregates: events joined / hosted, photos taken / liked,
//  and the user's sequential number.
//

import Foundation

/// User profile statistics for display.
struct ProfileStats {
    let eventsJoined: Int
    let eventsHosted: Int
    let photosTaken: Int
    let photosLiked: Int
    let userNumber: Int
}
