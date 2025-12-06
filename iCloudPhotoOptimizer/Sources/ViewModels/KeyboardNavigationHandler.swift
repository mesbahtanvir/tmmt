import SwiftUI
import Combine

/// Handles keyboard shortcuts and navigation throughout the app
@MainActor
class KeyboardNavigationHandler: ObservableObject {

    // MARK: - Published Properties

    @Published var focusedPhotoIndex: Int = 0
    @Published var focusedGroupIndex: Int = 0
    @Published var isInDetailMode: Bool = false

    // MARK: - Dependencies

    weak var appState: AppState?

    // MARK: - Key Bindings Configuration

    struct KeyBinding {
        let key: KeyEquivalent
        let modifiers: EventModifiers
        let action: String
        let description: String
    }

    static let keyBindings: [KeyBinding] = [
        KeyBinding(key: .space, modifiers: [], action: "toggleSelection", description: "Toggle selection"),
        KeyBinding(key: .rightArrow, modifiers: [], action: "nextPhoto", description: "Next photo"),
        KeyBinding(key: .leftArrow, modifiers: [], action: "previousPhoto", description: "Previous photo"),
        KeyBinding(key: .downArrow, modifiers: [], action: "nextGroup", description: "Next group"),
        KeyBinding(key: .upArrow, modifiers: [], action: "previousGroup", description: "Previous group"),
        KeyBinding(key: "k", modifiers: [], action: "keepCurrent", description: "Keep current photo"),
        KeyBinding(key: "d", modifiers: [], action: "deleteCurrent", description: "Mark for deletion"),
        KeyBinding(key: "s", modifiers: [], action: "skipGroup", description: "Skip group"),
        KeyBinding(key: .return, modifiers: [], action: "openDetail", description: "Open detail view"),
        KeyBinding(key: .escape, modifiers: [], action: "closeDetail", description: "Close detail/cancel"),
        KeyBinding(key: "a", modifiers: .command, action: "selectAll", description: "Select all"),
        KeyBinding(key: "a", modifiers: [.command, .shift], action: "deselectAll", description: "Deselect all"),
        KeyBinding(key: .delete, modifiers: .command, action: "moveToTrash", description: "Move to trash"),
        KeyBinding(key: "z", modifiers: .command, action: "undo", description: "Undo"),
        KeyBinding(key: "1", modifiers: .command, action: "gotoDashboard", description: "Go to Dashboard"),
        KeyBinding(key: "2", modifiers: .command, action: "gotoDuplicates", description: "Go to Duplicates"),
        KeyBinding(key: "3", modifiers: .command, action: "gotoSimilar", description: "Go to Similar"),
        KeyBinding(key: "4", modifiers: .command, action: "gotoQuality", description: "Go to Quality"),
        KeyBinding(key: "5", modifiers: .command, action: "gotoSettings", description: "Go to Settings"),
    ]

    // MARK: - Actions

    func handleKeyPress(key: KeyEquivalent, modifiers: EventModifiers) -> Bool {
        // Find matching key binding
        guard let binding = Self.keyBindings.first(where: { $0.key == key && $0.modifiers == modifiers }) else {
            return false
        }

        return executeAction(binding.action)
    }

    func executeAction(_ action: String) -> Bool {
        switch action {
        case "toggleSelection":
            toggleCurrentSelection()
        case "nextPhoto":
            navigateToNextPhoto()
        case "previousPhoto":
            navigateToPreviousPhoto()
        case "nextGroup":
            navigateToNextGroup()
        case "previousGroup":
            navigateToPreviousGroup()
        case "keepCurrent":
            keepCurrentPhoto()
        case "deleteCurrent":
            deleteCurrentPhoto()
        case "skipGroup":
            skipCurrentGroup()
        case "openDetail":
            openDetailView()
        case "closeDetail":
            closeDetailView()
        case "selectAll":
            selectAll()
        case "deselectAll":
            deselectAll()
        case "moveToTrash":
            moveSelectedToTrash()
        case "undo":
            undo()
        case "gotoDashboard":
            navigateToTab(.dashboard)
        case "gotoDuplicates":
            navigateToTab(.duplicates)
        case "gotoSimilar":
            navigateToTab(.similar)
        case "gotoQuality":
            navigateToTab(.quality)
        case "gotoSettings":
            navigateToTab(.settings)
        default:
            return false
        }

        return true
    }

    // MARK: - Navigation

    private func navigateToNextPhoto() {
        focusedPhotoIndex += 1
        clampPhotoIndex()
    }

    private func navigateToPreviousPhoto() {
        focusedPhotoIndex = max(0, focusedPhotoIndex - 1)
    }

    private func navigateToNextGroup() {
        focusedGroupIndex += 1
        focusedPhotoIndex = 0
        clampGroupIndex()
    }

    private func navigateToPreviousGroup() {
        focusedGroupIndex = max(0, focusedGroupIndex - 1)
        focusedPhotoIndex = 0
    }

    private func navigateToTab(_ tab: AppTab) {
        appState?.selectedTab = tab
    }

    // MARK: - Selection

    private func toggleCurrentSelection() {
        guard let photo = getCurrentPhoto() else { return }

        if appState?.selectedPhotoIDs.contains(photo.id) == true {
            appState?.selectedPhotoIDs.remove(photo.id)
        } else {
            appState?.selectedPhotoIDs.insert(photo.id)
        }
    }

    private func keepCurrentPhoto() {
        guard let photo = getCurrentPhoto() else { return }
        appState?.selectedPhotoIDs.remove(photo.id)

        // Mark others in group for deletion
        if let group = getCurrentGroup() {
            for otherPhoto in group where otherPhoto.id != photo.id {
                appState?.selectedPhotoIDs.insert(otherPhoto.id)
            }
        }

        navigateToNextGroup()
    }

    private func deleteCurrentPhoto() {
        guard let photo = getCurrentPhoto() else { return }
        appState?.selectedPhotoIDs.insert(photo.id)
        navigateToNextPhoto()
    }

    private func skipCurrentGroup() {
        // Remove all selections in current group
        if let group = getCurrentGroup() {
            for photo in group {
                appState?.selectedPhotoIDs.remove(photo.id)
            }
        }
        navigateToNextGroup()
    }

    private func selectAll() {
        appState?.selectAll()
    }

    private func deselectAll() {
        appState?.deselectAll()
    }

    private func moveSelectedToTrash() {
        appState?.moveSelectedToTrash()
    }

    private func undo() {
        // Trigger undo action
    }

    // MARK: - Detail View

    private func openDetailView() {
        isInDetailMode = true
    }

    private func closeDetailView() {
        if isInDetailMode {
            isInDetailMode = false
        }
    }

    // MARK: - Helpers

    private func getCurrentPhoto() -> Photo? {
        guard let appState = appState else { return nil }

        switch appState.selectedTab {
        case .duplicates:
            guard focusedGroupIndex < appState.duplicateGroups.count else { return nil }
            let group = appState.duplicateGroups[focusedGroupIndex]
            guard focusedPhotoIndex < group.photos.count else { return nil }
            return group.photos[focusedPhotoIndex]

        case .similar:
            guard focusedGroupIndex < appState.similarGroups.count else { return nil }
            let group = appState.similarGroups[focusedGroupIndex]
            guard focusedPhotoIndex < group.photos.count else { return nil }
            return group.photos[focusedPhotoIndex]

        case .quality:
            guard focusedPhotoIndex < appState.qualityIssues.count else { return nil }
            return appState.qualityIssues[focusedPhotoIndex].photo

        default:
            return nil
        }
    }

    private func getCurrentGroup() -> [Photo]? {
        guard let appState = appState else { return nil }

        switch appState.selectedTab {
        case .duplicates:
            guard focusedGroupIndex < appState.duplicateGroups.count else { return nil }
            return appState.duplicateGroups[focusedGroupIndex].photos

        case .similar:
            guard focusedGroupIndex < appState.similarGroups.count else { return nil }
            return appState.similarGroups[focusedGroupIndex].photos

        default:
            return nil
        }
    }

    private func clampPhotoIndex() {
        guard let group = getCurrentGroup() else { return }
        focusedPhotoIndex = min(focusedPhotoIndex, group.count - 1)
    }

    private func clampGroupIndex() {
        guard let appState = appState else { return }

        switch appState.selectedTab {
        case .duplicates:
            focusedGroupIndex = min(focusedGroupIndex, max(0, appState.duplicateGroups.count - 1))
        case .similar:
            focusedGroupIndex = min(focusedGroupIndex, max(0, appState.similarGroups.count - 1))
        default:
            break
        }
    }
}

// MARK: - Keyboard Shortcuts View Modifier

struct KeyboardShortcutsModifier: ViewModifier {
    @ObservedObject var handler: KeyboardNavigationHandler

    func body(content: Content) -> some View {
        content
            .background(
                KeyboardShortcutReceiver(handler: handler)
            )
    }
}

struct KeyboardShortcutReceiver: NSViewRepresentable {
    let handler: KeyboardNavigationHandler

    func makeNSView(context: Context) -> KeyboardView {
        let view = KeyboardView()
        view.handler = handler
        return view
    }

    func updateNSView(_ nsView: KeyboardView, context: Context) {
        nsView.handler = handler
    }

    class KeyboardView: NSView {
        var handler: KeyboardNavigationHandler?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard let handler = handler else {
                super.keyDown(with: event)
                return
            }

            let key = keyEquivalent(from: event)
            let modifiers = eventModifiers(from: event)

            Task { @MainActor in
                if !handler.handleKeyPress(key: key, modifiers: modifiers) {
                    super.keyDown(with: event)
                }
            }
        }

        private func keyEquivalent(from event: NSEvent) -> KeyEquivalent {
            if let char = event.charactersIgnoringModifiers?.first {
                return KeyEquivalent(char)
            }
            return KeyEquivalent(" ")
        }

        private func eventModifiers(from event: NSEvent) -> EventModifiers {
            var modifiers: EventModifiers = []
            if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
            if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
            if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
            if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
            return modifiers
        }
    }
}

extension View {
    func keyboardShortcuts(handler: KeyboardNavigationHandler) -> some View {
        modifier(KeyboardShortcutsModifier(handler: handler))
    }
}

// MARK: - Keyboard Shortcuts Help View

struct KeyboardShortcutsHelpView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    shortcutSection(title: "Navigation", shortcuts: [
                        ("→ / ←", "Navigate between photos"),
                        ("↓ / ↑", "Navigate between groups"),
                        ("⌘1-5", "Switch tabs"),
                        ("Return", "Open detail view"),
                        ("Escape", "Close/cancel")
                    ])

                    shortcutSection(title: "Selection", shortcuts: [
                        ("Space", "Toggle selection"),
                        ("⌘A", "Select all"),
                        ("⇧⌘A", "Deselect all")
                    ])

                    shortcutSection(title: "Actions", shortcuts: [
                        ("K", "Keep current photo"),
                        ("D", "Mark for deletion"),
                        ("S", "Skip group"),
                        ("⌘Delete", "Move selected to trash"),
                        ("⌘Z", "Undo")
                    ])
                }
                .padding()
            }
        }
        .frame(width: 400, height: 500)
    }

    private func shortcutSection(title: String, shortcuts: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ForEach(shortcuts, id: \.0) { shortcut in
                HStack {
                    Text(shortcut.0)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 80, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)

                    Text(shortcut.1)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
