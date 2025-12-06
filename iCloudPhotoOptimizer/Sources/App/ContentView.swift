import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            DetailView()
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Text("iCloud Photo Optimizer")
                    .font(.headline)
            }
        }
        .overlay(alignment: .bottom) {
            if appState.isScanning || appState.scanProgress.photosScanned > 0 {
                ScanProgressBar()
            }
        }
        .sheet(isPresented: .constant(false)) {
            // Confirmation dialogs will be presented here
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List(AppTab.allCases, selection: $appState.selectedTab) { tab in
            NavigationLink(value: tab) {
                Label {
                    HStack {
                        Text(tab.rawValue)
                        Spacer()
                        badgeView(for: tab)
                    }
                } icon: {
                    Image(systemName: tab.icon)
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }

    @ViewBuilder
    private func badgeView(for tab: AppTab) -> some View {
        let count: Int = {
            switch tab {
            case .duplicates:
                return appState.duplicateGroups.count
            case .similar:
                return appState.similarGroups.count
            case .quality:
                return appState.qualityIssues.count
            default:
                return 0
            }
        }()

        if count > 0 {
            Text("\(count)")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor(for: tab))
                .foregroundColor(.white)
                .clipShape(Capsule())
        }
    }

    private func badgeColor(for tab: AppTab) -> Color {
        switch tab {
        case .duplicates: return .red
        case .similar: return .orange
        case .quality: return .yellow
        default: return .gray
        }
    }
}

struct DetailView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            switch appState.selectedTab {
            case .dashboard:
                DashboardView()
            case .duplicates:
                DuplicatesView()
            case .similar:
                SimilarPhotosView()
            case .quality:
                QualityIssuesView()
            case .settings:
                SettingsView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ScanProgressBar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .foregroundColor(.blue)

            Text("Scanning: \(appState.scanProgress.photosScanned) / \(appState.scanProgress.totalPhotos) photos")
                .font(.callout)

            ProgressView(value: appState.scanProgress.percentComplete)
                .frame(width: 200)

            Text("\(Int(appState.scanProgress.percentComplete * 100))%")
                .font(.callout)
                .foregroundColor(.secondary)

            Spacer()

            if appState.isScanning {
                Button(action: { appState.pauseScan() }) {
                    Image(systemName: "pause.fill")
                }
                .buttonStyle(.borderless)
            } else if appState.isPaused {
                Button(action: { appState.resumeSession() }) {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.borderless)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(8)
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
