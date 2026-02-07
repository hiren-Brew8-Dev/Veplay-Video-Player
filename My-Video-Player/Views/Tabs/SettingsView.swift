import SwiftUI

struct SettingsView: View {
    @AppStorage("useFaceID") private var useFaceID = false  // Placeholder for Phase 4 completion
    @EnvironmentObject var viewModel: DashboardViewModel

    var body: some View {
        // NavigationView removed
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)

            Form {
                Section(header: Text("Privacy & Security").foregroundColor(.homeTextSecondary)) {
                    SettingsToggleRow(
                        icon: "faceid", title: "Use FaceID for Private Folder", isOn: $useFaceID,
                        iconColor: .green)
                }

                Section(header: Text("Support").foregroundColor(.homeTextSecondary)) {
                    Link("Privacy Policy", destination: URL(string: "https://example.com")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com")!)
                    Button("Share App") {
                        // Share logic
                    }
                }

                Section(header: Text("About").foregroundColor(.homeTextSecondary)) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.homeTextSecondary)
                    }
                    Text("Video Player - All In One Clone")
                        .font(.caption)
                        .foregroundColor(.homeTextSecondary)
                }
            }
            // Form background color tweak if needed
        }
        .navigationBarTitle("Settings", displayMode: .inline)
    }
}
