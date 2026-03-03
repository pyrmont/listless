import SwiftUI

struct SettingsView: View {
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    @Environment(\.dismiss) private var dismiss
    @AppStorage("headingText") private var headingText = "Items"
    @AppStorage("appearanceMode") private var appearanceMode = 0

    var body: some View {
        NavigationStack {
            List {
                Section("List Title") {
                    TextField("List Title", text: $headingText)
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $appearanceMode) {
                        Text("System").tag(0)
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    NavigationLink("iCloud Diagnostics") {
                        SyncDiagnosticsView(syncMonitor: syncMonitor)
                    }
                }

                Section {
                    NavigationLink("About") {
                        AboutView()
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
