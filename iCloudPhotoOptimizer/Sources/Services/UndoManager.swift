import Foundation
import Combine

/// Manages undo/redo operations for photo deletions
@MainActor
class PhotoUndoManager: ObservableObject {

    // MARK: - Types

    struct DeletionAction: Identifiable {
        let id = UUID()
        let photos: [Photo]
        let timestamp: Date
        let expiresAt: Date

        var isExpired: Bool {
            Date() > expiresAt
        }

        var timeRemaining: TimeInterval {
            expiresAt.timeIntervalSince(Date())
        }

        var formattedTimeRemaining: String {
            let seconds = Int(timeRemaining)
            if seconds <= 0 { return "Expired" }
            if seconds < 60 { return "\(seconds)s" }
            return "\(seconds / 60)m \(seconds % 60)s"
        }
    }

    enum UndoResult {
        case success(restoredCount: Int)
        case partial(restoredCount: Int, failedCount: Int)
        case failed(error: String)
        case expired
    }

    // MARK: - Configuration

    private struct Config {
        static let undoWindowSeconds: TimeInterval = 30
        static let maxHistoryItems = 10
    }

    // MARK: - Published Properties

    @Published private(set) var pendingActions: [DeletionAction] = []
    @Published private(set) var canUndo: Bool = false
    @Published var showUndoToast: Bool = false
    @Published var currentToastAction: DeletionAction?
    @Published var toastCountdown: Int = 30

    // MARK: - Private Properties

    private var history: [DeletionAction] = []
    private var cleanupTimer: Timer?
    private var toastTimer: Timer?
    private let photoLibraryManager = PhotoLibraryManager()

    // MARK: - Initialization

    init() {
        startCleanupTimer()
    }

    deinit {
        cleanupTimer?.invalidate()
        toastTimer?.invalidate()
    }

    // MARK: - Public API

    /// Record a deletion action that can be undone
    func recordDeletion(photos: [Photo]) {
        let action = DeletionAction(
            photos: photos,
            timestamp: Date(),
            expiresAt: Date().addingTimeInterval(Config.undoWindowSeconds)
        )

        pendingActions.append(action)
        history.append(action)

        // Trim history if needed
        if history.count > Config.maxHistoryItems {
            history.removeFirst()
        }

        canUndo = true
        showToast(for: action)
    }

    /// Undo the most recent deletion
    func undoLast() async -> UndoResult {
        guard let lastAction = pendingActions.last else {
            return .failed(error: "No actions to undo")
        }

        return await undo(action: lastAction)
    }

    /// Undo a specific deletion action
    func undo(action: DeletionAction) async -> UndoResult {
        guard !action.isExpired else {
            removeAction(action)
            return .expired
        }

        // Attempt to restore photos from trash
        var restored = 0
        var failed = 0

        for photo in action.photos {
            let success = await restoreFromTrash(photo)
            if success {
                restored += 1
            } else {
                failed += 1
            }
        }

        removeAction(action)
        hideToast()

        if failed == 0 {
            return .success(restoredCount: restored)
        } else if restored > 0 {
            return .partial(restoredCount: restored, failedCount: failed)
        } else {
            return .failed(error: "Could not restore photos")
        }
    }

    /// Dismiss undo option for an action (user chose not to undo)
    func dismissAction(_ action: DeletionAction) {
        removeAction(action)
        hideToast()
    }

    /// Get deletion history
    func getHistory() -> [DeletionAction] {
        return history.filter { !$0.isExpired }
    }

    /// Clear all history
    func clearHistory() {
        history.removeAll()
        pendingActions.removeAll()
        canUndo = false
        hideToast()
    }

    // MARK: - Private Methods

    private func removeAction(_ action: DeletionAction) {
        pendingActions.removeAll { $0.id == action.id }
        canUndo = !pendingActions.isEmpty
    }

    private func restoreFromTrash(_ photo: Photo) async -> Bool {
        // For iCloud Photos, we can't directly restore from Recently Deleted
        // For local files, we can try to restore from Trash

        switch photo.sourceType {
        case .localFolder:
            guard let path = photo.sourcePath else { return false }
            return await restoreLocalFile(originalPath: path)
        case .iCloudLibrary:
            // Cannot programmatically restore from Photos Recently Deleted
            // User must do this manually in Photos app
            return false
        }
    }

    private func restoreLocalFile(originalPath: String) async -> Bool {
        let fileManager = FileManager.default
        let fileName = URL(fileURLWithPath: originalPath).lastPathComponent

        // Check common Trash locations
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let trashURL = homeDir.appendingPathComponent(".Trash/\(fileName)")

        guard fileManager.fileExists(atPath: trashURL.path) else {
            return false
        }

        do {
            try fileManager.moveItem(at: trashURL, to: URL(fileURLWithPath: originalPath))
            return true
        } catch {
            print("Failed to restore file: \(error)")
            return false
        }
    }

    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.cleanupExpiredActions()
            }
        }
    }

    private func cleanupExpiredActions() {
        pendingActions.removeAll { $0.isExpired }
        canUndo = !pendingActions.isEmpty

        // Update toast if showing
        if let current = currentToastAction {
            if current.isExpired {
                hideToast()
            } else {
                toastCountdown = Int(current.timeRemaining)
            }
        }
    }

    private func showToast(for action: DeletionAction) {
        currentToastAction = action
        toastCountdown = Int(Config.undoWindowSeconds)
        showUndoToast = true

        // Start countdown timer
        toastTimer?.invalidate()
        toastTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.toastCountdown -= 1
                if self.toastCountdown <= 0 {
                    self.hideToast()
                }
            }
        }
    }

    private func hideToast() {
        showUndoToast = false
        currentToastAction = nil
        toastTimer?.invalidate()
        toastTimer = nil
    }
}

// MARK: - Undo Toast View

import SwiftUI

struct UndoToastView: View {
    @ObservedObject var undoManager: PhotoUndoManager
    let onUndo: () async -> Void

    var body: some View {
        if undoManager.showUndoToast, let action = undoManager.currentToastAction {
            HStack(spacing: 16) {
                // Success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                // Message
                VStack(alignment: .leading, spacing: 2) {
                    Text("Moved \(action.photos.count) photo\(action.photos.count == 1 ? "" : "s") to Trash")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(formatSize(action.photos.reduce(0) { $0 + $1.fileSize }))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Undo button
                Button("Undo") {
                    Task {
                        await onUndo()
                    }
                }
                .buttonStyle(.bordered)

                // Countdown
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 28, height: 28)

                    Circle()
                        .trim(from: 0, to: CGFloat(undoManager.toastCountdown) / 30.0)
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))

                    Text("\(undoManager.toastCountdown)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }

                // Dismiss button
                Button(action: {
                    undoManager.dismissAction(action)
                }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.regularMaterial)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3), value: undoManager.showUndoToast)
        }
    }

    private func formatSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Deletion History View

struct DeletionHistoryView: View {
    @ObservedObject var undoManager: PhotoUndoManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Deletions")
                    .font(.headline)

                Spacer()

                Button("Clear All") {
                    undoManager.clearHistory()
                }
                .buttonStyle(.borderless)
                .disabled(undoManager.getHistory().isEmpty)
            }
            .padding()

            Divider()

            // History list
            if undoManager.getHistory().isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trash.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("No recent deletions")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(undoManager.getHistory()) { action in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(action.photos.count) photo\(action.photos.count == 1 ? "" : "s")")
                                .font(.subheadline)

                            Text(action.timestamp, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !action.isExpired {
                            Button("Undo") {
                                Task {
                                    _ = await undoManager.undo(action: action)
                                }
                            }
                            .buttonStyle(.bordered)

                            Text(action.formattedTimeRemaining)
                                .font(.caption)
                                .foregroundColor(.orange)
                                .frame(width: 40)
                        } else {
                            Text("Expired")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
        .frame(width: 400, height: 300)
    }
}
