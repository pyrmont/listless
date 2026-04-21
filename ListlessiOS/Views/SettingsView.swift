import SwiftUI

struct SettingsView: View {
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearanceMode") private var appearanceMode = 0
    @AppStorage("colorTheme") private var colorThemeRaw = 0
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("debugMode") private var debugMode = false
    @AppStorage("showFPSOverlay") private var showFPSOverlay = false
    @AppStorage("didCompleteTutorial") private var didCompleteTutorial = false
    @State private var easterEggTaps = 0

    var body: some View {
        NavigationStack {
            List {
                Section("Theme") {
                    ForEach(ColorTheme.displayOrder) { theme in
                        Button {
                            colorThemeRaw = theme.rawValue
                        } label: {
                            HStack {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                                    .opacity(colorThemeRaw == theme.rawValue ? 1 : 0)
                                Text(theme.displayName)
                                Spacer()
                                LinearGradient(
                                    colors: [
                                        itemColor(forIndex: 0, total: 5, theme: theme),
                                        itemColor(forIndex: 2, total: 5, theme: theme),
                                        itemColor(forIndex: 4, total: 5, theme: theme),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: 80, height: 24)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                if UIDevice.current.userInterfaceIdiom == .phone {
                    Section("Interactions") {
                        Toggle("Haptics", isOn: $hapticsEnabled)
                    }
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $appearanceMode) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                if debugMode {
                    Section("Debugging") {
                        Toggle("FPS Overlay", isOn: $showFPSOverlay)
                        NavigationLink("iCloud Diagnostics") {
                            SyncDiagnosticsView(syncMonitor: syncMonitor)
                        }
                        NavigationLink("Perf Samples") {
                            PerfDebugView()
                        }
                        Button("Reset Tutorial") {
                            didCompleteTutorial = false
                            dismiss()
                        }
                    }
                }

                Section {
                    NavigationLink("About") {
                        AboutView()
                    }
                } footer: {
                    Text("Made in Tokyo from natural ones and zeros")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)
                        .onTapGesture {
                            easterEggTaps += 1
                            if easterEggTaps >= 4 {
                                debugMode.toggle()
                                if !debugMode {
                                    showFPSOverlay = false
                                }
                                easterEggTaps = 0
                            }
                        }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
