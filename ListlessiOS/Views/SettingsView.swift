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
                    NavigationLink("About") {
                        AboutView()
                    }
                } footer: {
                    Text("Made in Tokyo from natural ones and zeros")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)
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
