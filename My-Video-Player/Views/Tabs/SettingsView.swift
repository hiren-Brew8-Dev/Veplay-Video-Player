import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @AppStorage("useFaceID") private var useFaceID = false
    @EnvironmentObject var viewModel: DashboardViewModel
    @EnvironmentObject var navigationManager: NavigationManager
    @State private var webViewData: WebViewData? = nil

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }


    var body: some View {
        VStack(spacing: 0) {
            // Header (Matching FolderDetailView style)
            HStack(spacing: 12) {
                Button(action: {
                    navigationManager.pop()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.premiumCircleBackground)
                            .frame(width: AppDesign.Icons.circleButtonSize, height: AppDesign.Icons.circleButtonSize)
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: isIpad ? 22 : 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text("Settings")
                    .font(.system(size: isIpad ? 32 : 18, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
                    .padding(.leading, 8)
                
                Spacer()
            }
            .padding(.horizontal, AppDesign.Icons.horizontalPadding)
            .padding(.vertical, isIpad ? 24 : 8)
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
                                isOn: Binding(
                                    get: { useFaceID },
                                    set: { newValue in
                                        handleFaceIDToggle(newValue)
                                    }
                                ),
                                iconColor: .green
                            )
                        }
                    }

                    settingsSection(title: "Support") {
                        VStack(spacing: 0) {
                            settingsActionRow(icon: "doc.text.fill", title: "Privacy Policy", iconColor: .blue) {
                                webViewData = WebViewData(title: "Privacy Policy", url: "https://sites.google.com/view/shivshankarapps/privacy-policy")
                            }
                            Divider().background(Color.sheetDivider).padding(.leading, 56)
                            settingsActionRow(icon: "scroll.fill", title: "Terms of Service", iconColor: .orange) {
                                webViewData = WebViewData(title: "Terms of Service", url: "https://sites.google.com/view/shivshankarapps/terms-conditions")
                            }
                            Divider().background(Color.sheetDivider).padding(.leading, 56)
                            settingsActionRow(icon: "envelope.fill", title: "Contact Us", iconColor: .green) {
                                webViewData = WebViewData(title: "Contact Us", url: "https://sites.google.com/view/shivshankarapps/support")
                            }
                            Divider().background(Color.sheetDivider).padding(.leading, 56)
                            settingsActionRow(icon: "questionmark.circle.fill", title: "Support", iconColor: .blue) {
                                webViewData = WebViewData(title: "Support", url: "https://sites.google.com/view/shivshankarapps/support")
                            }
                            Divider().background(Color.sheetDivider).padding(.leading, 56)
                            settingsActionRow(icon: "heart.fill", title: "Rate App", iconColor: .red) {
                                guard let writeReviewURL = URL(string: "https://apps.apple.com/app/id\(Global.shared.appID)?action=write-review") else { return }
                                UIApplication.shared.open(writeReviewURL)
                            }
                            Divider().background(Color.sheetDivider).padding(.leading, 56)
                            settingsActionRow(icon: "square.and.arrow.up.fill", title: "Share with Friends", iconColor: .purple) {
                                let appLink = "https://apps.apple.com/app/id\(Global.shared.appID)"
                                viewModel.activityItems = ["Check out this awesome video player app!", URL(string: appLink)!]
                                viewModel.showShareSheetGlobal = true
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
                                    Text(appVersion)
                                        .font(.system(size: 14))
                                        .foregroundColor(.homeTextSecondary)
                                }
                                Spacer()
                            }
                        }
                        .padding(16)
                    }
                }
                .iPad { $0.frame(maxWidth: 600).padding(.top, 40) }
                .padding(.horizontal, AppDesign.Icons.horizontalPadding)
                .padding(.bottom, 100) // Space for tab bar
            }
            .iPad { $0.frame(maxWidth: .infinity, alignment: .center) }
            
        }
        .background(Color.homeBackground.edgesIgnoringSafeArea(.all))
        .fullScreenCover(item: $webViewData) { data in
            URLWebView(titleName: data.title, urlString: data.url)
        }
        .alert(isPresented: $showBiometricAlert) {
            Alert(
                title: Text("Face ID Unavailable"),
                message: Text(biometricAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - FaceID Handling
    
    @State private var showBiometricAlert = false
    @State private var biometricAlertMessage = ""

    private func handleFaceIDToggle(_ newValue: Bool) {
        let context = LAContext()
        var error: NSError?

        // 1. Check if Biometrics are available
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Case: FaceID/Passcode not set up or unavailable
            biometricAlertMessage = "Face ID or Passcode is not set up on this device. Please enable it in iOS Settings to use this feature."
            showBiometricAlert = true
            // Ensure toggle remains off if it was off
            if newValue { useFaceID = false }
            return
        }

        // 2. If turning OFF, require authentication
        if !newValue {
            // User wants to DISABLE FaceID -> Verify Identity first
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Verify to disable FaceID Protection") { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        // Auth successful, allow disabling
                        self.useFaceID = false
                    } else {
                        // Auth failed, keep it ON
                        self.useFaceID = true
                        if let error = authenticationError {
                             print("Auth failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        } else {
            // 3. If turning ON, we might also want to verify simply to ensure it works, 
            // but usually it's okay to just enable. However, to be "proper", let's verify.
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Verify to enable FaceID Protection") { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.useFaceID = true
                    } else {
                        self.useFaceID = false
                    }
                }
            }
        }
    }

    // MARK: - Components

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: isIpad ? 16 : 12) {
            Text(title.uppercased())
                .font(.system(size: isIpad ? 16 : 13, weight: .bold))
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
                        .font(.system(size: isIpad ? 20 : 16, weight: .semibold))
                        .foregroundColor(.homeTextPrimary)
                    Text(subtitle)
                        .font(.system(size: isIpad ? 16 : 12))
                        .foregroundColor(.homeTextSecondary)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .homeAccent))
        .padding(isIpad ? 20 : 16)
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
