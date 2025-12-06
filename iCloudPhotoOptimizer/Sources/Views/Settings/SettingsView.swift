import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Analysis Settings
                analysisSettings

                Divider()

                // Quality Detection Settings
                qualitySettings

                Divider()

                // Storage & Cache
                storageSettings

                Divider()

                // About
                aboutSection
            }
            .padding(32)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Analysis Settings

    private var analysisSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis Settings")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Similarity Threshold")
                    Spacer()
                    Text("\(Int(appState.settings.similarityThreshold * 100))%")
                        .foregroundColor(.secondary)
                }

                Slider(value: $appState.settings.similarityThreshold, in: 0.5...0.95)

                Text("Lower values find more similar photos but may include false positives")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Quality Settings

    private var qualitySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quality Detection")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                Toggle("Detect blurry photos", isOn: $appState.settings.detectBlurry)

                if appState.settings.detectBlurry {
                    HStack {
                        Text("Blur threshold")
                            .foregroundColor(.secondary)
                        Slider(value: $appState.settings.blurThreshold, in: 50...200)
                            .frame(width: 200)
                        Text("\(Int(appState.settings.blurThreshold))")
                            .frame(width: 40)
                    }
                    .padding(.leading, 20)
                }

                Divider()

                Toggle("Detect dark photos", isOn: $appState.settings.detectDark)

                if appState.settings.detectDark {
                    HStack {
                        Text("Darkness threshold")
                            .foregroundColor(.secondary)
                        Slider(value: $appState.settings.darknessThreshold, in: 0.1...0.4)
                            .frame(width: 200)
                        Text("\(Int(appState.settings.darknessThreshold * 100))%")
                            .frame(width: 40)
                    }
                    .padding(.leading, 20)
                }

                Divider()

                Toggle("Detect overexposed photos", isOn: $appState.settings.detectOverexposed)

                if appState.settings.detectOverexposed {
                    HStack {
                        Text("Brightness threshold")
                            .foregroundColor(.secondary)
                        Slider(value: $appState.settings.brightnessThreshold, in: 0.7...0.95)
                            .frame(width: 200)
                        Text("\(Int(appState.settings.brightnessThreshold * 100))%")
                            .frame(width: 40)
                    }
                    .padding(.leading, 20)
                }

                Divider()

                Toggle("Detect low resolution photos", isOn: $appState.settings.detectLowResolution)

                if appState.settings.detectLowResolution {
                    HStack {
                        Text("Minimum resolution")
                            .foregroundColor(.secondary)
                        Picker("", selection: $appState.settings.minimumResolution) {
                            Text("720p").tag(720)
                            Text("1080p").tag(1080)
                            Text("4K").tag(2160)
                        }
                        .frame(width: 100)
                    }
                    .padding(.leading, 20)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Storage Settings

    private var storageSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage & Cache")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Analysis Cache")
                            .font(.headline)
                        Text("Stores analysis results for faster subsequent scans")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(formatBytes(getCacheSize()))
                        .foregroundColor(.secondary)

                    Button("Clear Cache") {
                        clearCache()
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading) {
                        Text("Saved Session")
                            .font(.headline)
                        Text("Resume interrupted scans")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if appState.hasSavedSession {
                        Text("Session available")
                            .foregroundColor(.green)

                        Button("Clear Session") {
                            clearSession()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Text("No saved session")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("iCloud Photo Optimizer")
                        .font(.headline)
                    Spacer()
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label("All processing is done locally on your Mac", systemImage: "lock.shield")
                    Label("No photos are uploaded to any server", systemImage: "icloud.slash")
                    Label("Uses Apple's on-device ML for analysis", systemImage: "cpu")
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Divider()

                HStack {
                    Button("View on GitHub") {
                        // Open GitHub link
                    }
                    .buttonStyle(.link)

                    Spacer()

                    Button("Report an Issue") {
                        // Open issue tracker
                    }
                    .buttonStyle(.link)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - Helpers

    private func getCacheSize() -> Int64 {
        // TODO: Implement actual cache size calculation
        return 0
    }

    private func clearCache() {
        // TODO: Implement cache clearing
    }

    private func clearSession() {
        // TODO: Implement session clearing
        appState.hasSavedSession = false
    }

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .frame(width: 700, height: 800)
}
