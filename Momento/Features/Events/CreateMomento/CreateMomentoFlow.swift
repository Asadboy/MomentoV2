//
//  CreateMomentoFlow.swift
//  Momento
//
//  Multi-step wizard for creating a new Momento
//

import SwiftUI

struct CreateMomentoFlow: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabaseManager = SupabaseManager.shared
    
    // Step tracking
    @State private var currentStep = 1
    
    // Form data
    @State private var momentoName = ""
    @State private var startsAt = Date().addingTimeInterval(3600) // 1 hour from now
    @State private var endsAt = Date().addingTimeInterval(13 * 3600) // 12 hours after start
    @State private var releaseAt = Date().addingTimeInterval(25 * 3600) // 24 hours after start
    @State private var joinCode = ""
    
    // State
    @State private var isCreating = false
    @State private var createdEvent: Event?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var hostName: String = ""
    
    /// Callback when evento is created
    var onEventCreated: ((Event) -> Void)?
    
    var body: some View {
        ZStack {
            // Steps
            if currentStep == 1 {
                CreateStep1NameView(
                    momentoName: $momentoName,
                    onNext: { goToStep(2) },
                    onCancel: { dismiss() }
                )
            } else if currentStep == 2 {
                CreateStep2ConfigureView(
                    eventName: momentoName,
                    startsAt: $startsAt,
                    endsAt: $endsAt,
                    releaseAt: $releaseAt,
                    onNext: { createMomento() },
                    onBack: { goToStep(1) }
                )
            } else if currentStep == 3 {
                CreateStep3ShareView(
                    momentoName: momentoName,
                    joinCode: joinCode,
                    startsAt: startsAt,
                    hostName: hostName,
                    onDone: { finishFlow() }
                )
            }

            // Loading overlay
            if isCreating {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)

                    Text("Creating your event...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await fetchHostName()
        }
    }

    // MARK: - Fetch Host Name

    private func fetchHostName() async {
        guard let userId = supabaseManager.currentUser?.id else { return }

        do {
            let profile = try await supabaseManager.getUserProfile(userId: userId)
            await MainActor.run {
                hostName = profile.displayName ?? profile.username
            }
        } catch {
            debugLog("[CreateMomento] Failed to fetch host name: \(error)")
            await MainActor.run {
                hostName = "Host"
            }
        }
    }
    
    // MARK: - Navigation
    
    private func goToStep(_ step: Int) {
        withAnimation {
            currentStep = step
        }
    }
    
    // MARK: - Create Momento
    
    private func createMomento() {
        isCreating = true

        // Generate join code
        joinCode = generateJoinCode()

        debugLog("[CreateMomento] Creating: \(momentoName)")
        debugLog("[CreateMomento] Code: \(joinCode)")

        Task {
            do {
                debugLog("[CreateMomento] 1/4 — calling createEvent...")
                let eventModel = try await supabaseManager.createEvent(
                    name: momentoName.trimmingCharacters(in: .whitespacesAndNewlines),
                    startsAt: startsAt,
                    joinCode: joinCode
                )
                debugLog("[CreateMomento] 2/4 — createEvent returned, building Event...")

                let event = Event(fromSupabase: eventModel)

                AnalyticsManager.shared.track(.eventCreated, properties: [
                    "event_id": event.id,
                    "event_name": event.name
                ])

                debugLog("[CreateMomento] 3/4 — updating UI state")
                createdEvent = event
                isCreating = false
                currentStep = 3
                debugLog("[CreateMomento] 4/4 — isCreating=\(isCreating), step=\(currentStep)")

            } catch {
                debugLog("[CreateMomento] ❌ CAUGHT ERROR: \(error)")
                debugLog("[CreateMomento] ❌ Error type: \(type(of: error))")
                isCreating = false
                errorMessage = "Failed to create event: \(error.localizedDescription)"
                showError = true
            }
        }
    }
    
    private func finishFlow() {
        if let event = createdEvent {
            onEventCreated?(event)
        }
        dismiss()
    }
    
    private func generateJoinCode() -> String {
        // 6 character code using unambiguous characters
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in characters.randomElement()! })
    }
}

#Preview {
    CreateMomentoFlow()
}

