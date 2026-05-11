//
//  UploadFailureBanner.swift
//  Momento
//
//  Slim banner at the top of the home screen surfacing photos that failed
//  to upload after exhausting retries. Without this, failed uploads sit
//  silently in OfflineSyncManager — the user has no way to know a photo
//  never made it to the server.
//
//  Tap to retry: resets retry counts and re-runs the queue. The banner
//  hides itself once everything succeeds.
//

import SwiftUI

struct UploadFailureBanner: View {
    @ObservedObject var sync: OfflineSyncManager

    var body: some View {
        if sync.failedCount > 0 {
            Button(action: retry) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.orange)

                    Text(failureCopy)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)

                    Spacer()

                    Text("Retry")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.orange.opacity(0.7)))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.orange.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var failureCopy: String {
        let n = sync.failedCount
        return n == 1
            ? "1 shot couldn't upload"
            : "\(n) shots couldn't upload"
    }

    private func retry() {
        HapticsManager.shared.light()
        sync.retryFailedUploads()
    }
}

#Preview {
    let sync = OfflineSyncManager.shared
    return ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            UploadFailureBanner(sync: sync)
            Spacer()
        }
    }
}
