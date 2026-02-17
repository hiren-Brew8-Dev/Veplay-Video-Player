import SwiftUI
import LocalAuthentication

struct SettingsView: View {
    @AppStorage("useFaceID") private var useFaceID = false
    @AppStorage("isBackgroundPlayEnabled") private var isBackgroundPlayEnabled = false
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
                    HapticsManager.shared.generate(.medium)
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
            .background(Color.clear)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Privacy & Security Section
                    settingsSection(title: "Privacy & Security") {
                        VStack(spacing: 0) {
                            settingsToggleRow(
                                icon: "lock.shield.fill",
                                title: "App Lock",
                                subtitle: "Secure app with device authentication",
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
                    
                    // Playback Section
                    settingsSection(title: "Playback") {
                        VStack(spacing: 0) {
                            settingsToggleRow(
                                icon: "music.note.list",
                                title: "Background Play",
                                subtitle: "Keep playing audio when app is in background",
                                isOn: Binding(
                                    get: { isBackgroundPlayEnabled },
                                    set: { newValue in
                                        handleBackgroundPlayToggle(newValue)
                                    }
                                ),
                                iconColor: .purple
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
            .scrollBounceBehavior(.basedOnSize)
            .iPad { $0.frame(maxWidth: .infinity, alignment: .center) }
            
        }
        .hideNavigationBar()
        .background(AppGlobalBackground().ignoresSafeArea())
        .fullScreenCover(item: $webViewData) { data in
            URLWebView(titleName: data.title, urlString: data.url)
        }
        .alert(isPresented: $showBiometricAlert) {
            Alert(
                title: Text("Device Security Required"),
                message: Text(biometricAlertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            if !Global.shared.getIsUserPro() {
                isBackgroundPlayEnabled = false
            }
        }
    }

    // MARK: - FaceID Handling
    
    @State private var showBiometricAlert = false
    @State private var biometricAlertMessage = ""
    
    // MARK: - Background Play Handling
    
    private func handleBackgroundPlayToggle(_ newValue: Bool) {
        HapticsManager.shared.generate(.selection)
        if newValue {
            if Global.shared.getIsUserPro() {
                isBackgroundPlayEnabled = true
            } else {
                // Not a pro user - show paywall and reset toggle
                isBackgroundPlayEnabled = false
                navigationManager.push(.paywall(isFromOnboarding: false))
            }
        } else {
            isBackgroundPlayEnabled = false
        }
    }

    private func handleFaceIDToggle(_ newValue: Bool) {
        HapticsManager.shared.generate(.selection)
        if newValue {
            // User wants to ENABLE App Lock
            enableAppLock()
        } else {
            // User wants to DISABLE App Lock
            disableAppLock()
        }
    }
    
    private func enableAppLock() {
        // Check if device has security set up (Face ID/Touch ID OR device passcode)
        let (canAuth, errorMessage) = BiometricAuthService.shared.canAuthenticate()
        
        if !canAuth {
            // No device security set up - show alert
            biometricAlertMessage = errorMessage ?? "Please set up device security in iPhone Settings to use App Lock."
            showBiometricAlert = true
            useFaceID = false
            return
        }
        
        // Device has security - verify to enable
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Verify to enable App Lock") { success, error in
            DispatchQueue.main.async {
                if success {
                    self.useFaceID = true
                } else {
                    self.useFaceID = false
                    // Don't show error for user cancellation
                    if let laError = error as? LAError, laError.code != .userCancel {
                        self.biometricAlertMessage = laError.localizedDescription
                        self.showBiometricAlert = true
                    }
                }
            }
        }
    }
    
    private func disableAppLock() {
        // Require authentication to disable
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Verify to disable App Lock") { success, error in
            DispatchQueue.main.async {
                if success {
                    self.useFaceID = false
                } else {
                    // Auth failed - keep it enabled
                    self.useFaceID = true
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
        Button(action: {
            HapticsManager.shared.generate(.selection)
            action()
        }) {
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
