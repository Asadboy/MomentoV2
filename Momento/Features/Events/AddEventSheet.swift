//
//  AddEventSheet.swift
//  Momento
//
//  Created by Asad on 02/11/2025.
//
//  MODULAR ARCHITECTURE: Reusable form component
//  This sheet component handles event creation UI.
//  Emoji choices are passed in from the parent component.

import SwiftUI

/// A reusable sheet for creating an Event.
/// Parent owns the data via @State and passes it in via @Binding.
/// This separation allows the sheet to be reused anywhere in the app.
struct AddEventSheet: View {
    @Binding var title: String
    @Binding var releaseAt: Date
    @Binding var emoji: String

    let emojiChoices: [String]  // Emoji choices passed from parent
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Momento title", text: $title)
                        .submitLabel(.done)

                    DatePicker("Releases at",
                               selection: $releaseAt,
                               displayedComponents: [.date, .hourAndMinute])
                }

                Section("Cover") {
                    Picker("Emoji", selection: $emoji) {
                        ForEach(emojiChoices, id: \.self) { e in
                            Text(e).tag(e)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden) // Hide default form background
            .background(
                // Dark background matching main view
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.08, green: 0.06, blue: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("New Momento")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
