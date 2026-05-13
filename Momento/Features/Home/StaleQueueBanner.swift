//
//  StaleQueueBanner.swift
//  Momento
//
//  Shown once at cold launch when OfflineSyncManager.loadQueue dropped
//  queue entries because their local files had gone missing (low-disk
//  cleanup by iOS, app uninstall+reinstall, etc.). Without this, the
//  shot vanishes silently and the user has no idea anything was lost.
//
//  Informational, not actionable — the original photo is gone from the
//  upload queue's local storage, so there's nothing to retry. A close
//  button dismisses the banner; it doesn't return until next launch with
//  fresh stale entries.
//

import SwiftUI

struct StaleQueueBanner: View {
    @ObservedObject var sync: OfflineSyncManager

    var body: some View {
        if sync.staleEntriesAtLaunch > 0 {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.yellow)

                Text(copy)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                Spacer()

                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yellow.opacity(0.30), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var copy: String {
        let n = sync.staleEntriesAtLaunch
        return n == 1
            ? "1 shot couldn't be recovered"
            : "\(n) shots couldn't be recovered"
    }

    private func dismiss() {
        HapticsManager.shared.light()
        sync.acknowledgeStaleEntries()
    }
}

#Preview {
    let sync = OfflineSyncManager.shared
    sync.staleEntriesAtLaunch = 2
    return ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            StaleQueueBanner(sync: sync)
            Spacer()
        }
    }
}
