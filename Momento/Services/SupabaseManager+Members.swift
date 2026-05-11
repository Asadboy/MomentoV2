//
//  SupabaseManager+Members.swift
//  Momento
//
//  Membership queries: counting members in an event, and hydrating the
//  "people-dots" roster used by the lobby hero. Photo counts that read the
//  photos table live in the Photos extension.
//

import Foundation
import Supabase

extension SupabaseManager {

    /// Number of members in an event. HEAD-only count query.
    func getEventMemberCount(eventId: UUID) async throws -> Int {
        try await client
            .from("event_members")
            .select("*", head: true, count: .exact)
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .count ?? 0
    }

    /// Fetch all members of an event with their profile info and shot counts.
    /// Returns members sorted: current user first, then by shots taken
    /// descending. Profiles + per-member photo counts are fetched in parallel
    /// so the latency is bounded by the slowest single member, not the sum.
    func getEventMembersWithShots(eventId: UUID) async throws -> [MemberWithShots] {
        guard let currentUserId = currentUser?.id else {
            throw SupabaseError.userNotAuthenticated
        }

        let members: [EventMember] = try await client
            .from("event_members")
            .select()
            .eq("event_id", value: eventId.uuidString)
            .execute()
            .value

        if members.isEmpty { return [] }

        let results = try await withThrowingTaskGroup(of: MemberWithShots?.self) { group in
            for member in members {
                group.addTask {
                    let profile = try? await self.getUserProfile(userId: member.userId)
                    let count = (try? await self.getPhotoCount(eventId: eventId, userId: member.userId)) ?? 0
                    guard let profile else { return nil }
                    return MemberWithShots(
                        userId: member.userId.uuidString,
                        username: profile.username,
                        displayName: profile.displayName,
                        avatarUrl: profile.avatarUrl,
                        shotsTaken: count
                    )
                }
            }

            var memberShots: [MemberWithShots] = []
            for try await result in group {
                if let member = result {
                    memberShots.append(member)
                }
            }
            return memberShots
        }

        var memberShots = results
        debugLog("[MembersWithShots] Event \(eventId.uuidString.prefix(8)): \(members.count) members, \(memberShots.count) with profiles")

        memberShots.sort { a, b in
            if a.userId == currentUserId.uuidString { return true }
            if b.userId == currentUserId.uuidString { return false }
            return a.shotsTaken > b.shotsTaken
        }

        return memberShots
    }
}
