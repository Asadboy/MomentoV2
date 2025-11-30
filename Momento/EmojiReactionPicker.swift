//
//  EmojiReactionPicker.swift
//  Momento
//
//  Quick emoji reaction picker for photos
//

import SwiftUI

struct EmojiReactionPicker: View {
    let onEmojiSelected: (String) -> Void
    
    private let emojis = ["❤️", "😂", "🔥", "👏", "😍", "🎉", "😮", "👀"]
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(emojis, id: \.self) { emoji in
                Button(action: {
                    HapticsManager.shared.light()
                    onEmojiSelected(emoji)
                }) {
                    Text(emoji)
                        .font(.system(size: 32))
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
                .blur(radius: 10)
        )
    }
}

struct EmojiReactionDisplay: View {
    let reactions: [String: String] // [userId: emoji]
    
    var body: some View {
        if !reactions.isEmpty {
            HStack(spacing: 8) {
                ForEach(Array(reactionCounts.keys.sorted()), id: \.self) { emoji in
                    if let count = reactionCounts[emoji] {
                        HStack(spacing: 4) {
                            Text(emoji)
                                .font(.system(size: 20))
                            
                            if count > 1 {
                                Text("\(count)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        )
                    }
                }
            }
        }
    }
    
    // Count occurrences of each emoji
    private var reactionCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for emoji in reactions.values {
            counts[emoji, default: 0] += 1
        }
        return counts
    }
}

#Preview {
    VStack(spacing: 40) {
        EmojiReactionPicker { emoji in
            print("Selected: \(emoji)")
        }
        
        EmojiReactionDisplay(reactions: [
            "user1": "❤️",
            "user2": "❤️",
            "user3": "😂",
            "user4": "🔥"
        ])
    }
    .padding()
    .background(Color.black)
}

