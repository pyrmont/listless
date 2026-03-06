import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image("AboutIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 22))

                    Text("Listless")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 20)

                    VStack(spacing: 4) {
                        Text("Programming")
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                        Text("Claude Code and OpenAI Codex")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.bottom, 8)

                    VStack(spacing: 4) {
                        Text("Direction")
                            .font(.caption)
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                        Text("Michael Camilleri")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Link(destination: URL(string: "https://apps.inqk.net/listless")!) {
                    Label("Website", systemImage: "globe")
                }
                Link(destination: URL(string: "https://github.com/pyrmont/listless")!) {
                    Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            Section {
                Text(
                    "Thank you to my wife, daughter and sons for their love and inspiration."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
