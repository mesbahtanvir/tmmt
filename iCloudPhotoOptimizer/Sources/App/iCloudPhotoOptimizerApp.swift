import SwiftUI

@main
struct iCloudPhotoOptimizerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}

            CommandMenu("Scan") {
                Button("Start Scan") {
                    appState.startScan()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Pause Scan") {
                    appState.pauseScan()
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(!appState.isScanning)

                Divider()

                Button("Resume Previous Session") {
                    appState.resumeSession()
                }
                .disabled(!appState.hasSavedSession)
            }

            CommandMenu("Selection") {
                Button("Select All") {
                    appState.selectAll()
                }
                .keyboardShortcut("a", modifiers: .command)

                Button("Deselect All") {
                    appState.deselectAll()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])

                Divider()

                Button("Move Selected to Trash") {
                    appState.moveSelectedToTrash()
                }
                .keyboardShortcut(.delete, modifiers: .command)
            }
        }
    }
}
