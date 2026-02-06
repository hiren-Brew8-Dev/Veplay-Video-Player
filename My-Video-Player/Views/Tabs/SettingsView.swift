import SwiftUI

struct SettingsView: View {
    @AppStorage("autoPlayNext") private var autoPlayNext = true
    @AppStorage("useFaceID") private var useFaceID = false  // Placeholder for Phase 4 completion
    @EnvironmentObject var viewModel: DashboardViewModel

    var body: some View {
        // NavigationView removed
        ZStack {
            Color.themeBackground.edgesIgnoringSafeArea(.all)

            Form {
                Section(header: Text("Player").foregroundColor(.gray)) {
                    SettingsToggleRow(
                        icon: "play.rectangle.fill", title: "Auto Play Next Video",
                        isOn: $autoPlayNext, iconColor: .orange)
                }

                Section(header: Text("Privacy & Security").foregroundColor(.gray)) {
                    SettingsToggleRow(
                        icon: "faceid", title: "Use FaceID for Private Folder", isOn: $useFaceID,
                        iconColor: .green)
                }

                Section(header: Text("Support").foregroundColor(.gray)) {
                    Link("Privacy Policy", destination: URL(string: "https://example.com")!)
                    Link("Terms of Service", destination: URL(string: "https://example.com")!)
                    Button("Share App") {
                        // Share logic
                    }
                }

                Section(header: Text("About").foregroundColor(.gray)) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.gray)
                    }
                    Text("Video Player - All In One Clone")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            // Form background color tweak if needed
        }
        .navigationBarTitle("Settings", displayMode: .inline)
    }
}
