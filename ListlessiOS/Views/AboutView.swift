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
                VStack(spacing: 12) {
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
                        .padding(.bottom, 8)

                    Text("Made in Tokyo by Michael Camilleri")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
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
                VStack(alignment: .leading, spacing: 12) {
                    Text(
                        "Thank you to my wife, daughter and sons for their love and inspiration."
                    )
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}
