import SwiftUI

struct SettingsView: View {
    @AppStorage("useFaceID") private var useFaceID = false
    @EnvironmentObject var viewModel: DashboardViewModel

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header (Matching FolderDetailView style)
            HStack(spacing: 12) {
                Button(action: {
                    if !viewModel.navigationPath.isEmpty {
                        viewModel.navigationPath.removeLast()
                    } else {
                        dismiss()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.premiumCircleBackground)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text("Settings")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.homeBackground)

            ScrollView {
                VStack(spacing: 24) {
                    // Privacy & Security Section
                    settingsSection(title: "Privacy & Security") {
                        VStack(spacing: 0) {
                            settingsToggleRow(
                                icon: "faceid",
                                title: "FaceID Protection",
                                subtitle: "Secure app with biometric lock",
                                isOn: $useFaceID,
                                iconColor: .green
                            )
                        }
                    }

                    // Support Section
                    settingsSection(title: "Support") {
                        VStack(spacing: 0) {
                            settingsLinkRow(icon: "doc.text.fill", title: "Privacy Policy", url: "https://example.com", iconColor: .blue)
                            Divider().background(Color.sheetDivider).padding(.leading, 56)
                            settingsLinkRow(icon: "scroll.fill", title: "Terms of Service", url: "https://example.com", iconColor: .orange)
                            Divider().background(Color.sheetDivider).padding(.leading, 56)
                            settingsActionRow(icon: "heart.fill", title: "Rate App", iconColor: .red) {
                                // Rate logic
                            }
                            Divider().background(Color.sheetDivider).padding(.leading, 56)
                            settingsActionRow(icon: "square.and.arrow.up.fill", title: "Share with Friends", iconColor: .purple) {
                                // Share logic
                            }
                        }
                    }

                    // About Section
                    settingsSection(title: "About") {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Version")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.homeTextPrimary)
                                    Text("1.0.0 (Build 1)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.homeTextSecondary)
                                }
                                Spacer()
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.homeTextSecondary)
                            }
                            
                            Divider().background(Color.sheetDivider)
                            
                            Text("The ultimate all-in-one video player experience. Built for speed and elegance.")
                                .font(.system(size: 14))
                                .foregroundColor(.homeTextSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 100) // Space for tab bar
            }
        }
//        .background(Color.homeBackground.edgesIgnoringSafeArea(.all))
    }

    // MARK: - Components

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.homeTextSecondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                content()
            }
            .background(Color.premiumCardBackground)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.premiumCardBorder, lineWidth: 1)
            )
        }
    }

    private func settingsToggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>, iconColor: Color) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.homeTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.homeTextSecondary)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .homeAccent))
        .padding(16)
    }

    private func settingsLinkRow(icon: String, title: String, url: String, iconColor: Color) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.homeTextPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.homeTextSecondary.opacity(0.5))
            }
            .padding(16)
        }
    }

    private func settingsActionRow(icon: String, title: String, iconColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.homeTextPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.homeTextSecondary.opacity(0.5))
            }
            .contentShape(Rectangle())
            .padding(16)
        }
        .buttonStyle(.scalable)
    }
}
