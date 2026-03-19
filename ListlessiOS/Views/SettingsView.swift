import SwiftUI

struct SettingsView: View {
    @ObservedObject var syncMonitor: CloudKitSyncMonitor
    @Environment(\.dismiss) private var dismiss
    @AppStorage("headingText") private var headingText = "Items"
    @AppStorage("appearanceMode") private var appearanceMode = 0
    @AppStorage("colorTheme") private var colorThemeRaw = 0

    var body: some View {
        NavigationStack {
            List {
                Section("List Title") {
                    TextField("List Title", text: $headingText)
                }

                Section("Theme") {
                    ForEach(ColorTheme.allCases) { theme in
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
                                        taskColor(forIndex: 0, total: 5, theme: theme),
                                        taskColor(forIndex: 2, total: 5, theme: theme),
                                        taskColor(forIndex: 4, total: 5, theme: theme),
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
