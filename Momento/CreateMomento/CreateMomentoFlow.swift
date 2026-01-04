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
    @State private var joinCode = ""
    
    // State
    @State private var isCreating = false
    @State private var createdEvent: Event?
    @State private var errorMessage: String?
    
    /// Callback when evento is created
    var onEventCreated: ((Event) -> Void)?
    
    var body: some View {
        ZStack {
            // Steps
            Group {
                switch currentStep {
                case 1:
                    CreateStep1NameView(
                        momentoName: $momentoName,
                        onNext: { goToStep(2) },
                        onCancel: { dismiss() }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case 2:
                    CreateStep2TimesView(
                        momentoName: momentoName,
                        startsAt: $startsAt,
                        onNext: { createMomento() },
                        onBack: { goToStep(1) }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                case 3:
                    CreateStep3ShareView(
                        momentoName: momentoName,
                        joinCode: joinCode,
                        startsAt: startsAt,
                        onDone: { finishFlow() }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                    
                default:
                    EmptyView()
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: currentStep)
            
            // Loading overlay
            if isCreating {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Creating your momento...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
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
        
        print("[CreateMomento] Creating: \(momentoName)")
        print("[CreateMomento] Code: \(joinCode)")
        
        Task {
            do {
                let eventModel = try await supabaseManager.createEvent(
                    title: momentoName.trimmingCharacters(in: .whitespacesAndNewlines),
                    startsAt: startsAt,
                    joinCode: joinCode
                )
                
                let event = Event(fromSupabase: eventModel)
                
                await MainActor.run {
                    createdEvent = event
                    isCreating = false
                    goToStep(3)
                }
                
                print("[CreateMomento] Success!")
                
            } catch {
                print("[CreateMomento] Error: \(error)")
                await MainActor.run {
                    isCreating = false
                    errorMessage = "Failed to create momento: \(error.localizedDescription)"
                }
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

