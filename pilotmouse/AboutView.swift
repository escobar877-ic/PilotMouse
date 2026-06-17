import SwiftUI

struct AboutView: View {
    private let principles = [
        "Local only",
        "No account",
        "No subscription",
        "No telemetry",
        "Settings are stored locally"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("MousePilot")
                    .font(.largeTitle.bold())
                Text("Version 0.1.0")
                    .foregroundStyle(.secondary)
                Text("Local mouse customization tool for macOS")
                    .font(.headline)
                    .padding(.top, 6)
            }

            Text("Built for simple mouse button and scrolling customization without accounts, subscriptions, telemetry, profiles, or cloud sync.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(principles, id: \.self) { principle in
                    Label(principle, systemImage: "checkmark.circle")
                }
            }

            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 4)
    }
}

#Preview {
    AboutView()
}
