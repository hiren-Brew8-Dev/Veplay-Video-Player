import SwiftUI

struct CastDevicePickerView: View {
    @ObservedObject var discoveryManager = DiscoveryManager()
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    let isLandscape: Bool
    var onBack: () -> Void
    
    // Check if we've already shown permission prompt before
    @AppStorage("hasShownCastPermissionPrompt") private var hasShownPermissionPrompt = false
    @State private var showPermissionView: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            if !isLandscape {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.premiumCircleBackground)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Device List")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Invisible spacer for symmetry
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, isLandscape ? 16 : 0)
            .padding(.bottom, 20)
            
            // Content
            if showPermissionView && !hasShownPermissionPrompt {
                permissionContent
            } else if discoveryManager.permissionDenied {
                permissionDeniedContent
            } else {
                discoveryContent
            }
        }
        
        .padding(.bottom, 0)
        .applyIf(isLandscape) { $0.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) }
        .applyIf(!isLandscape) { $0.padding(.bottom, 20) }
        .background(
            LinearGradient(
                colors: [.premiumGradientTop, .premiumGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .applyIf(isLandscape) { view in
            view.cornerRadiusLocal(24, corners: [.topLeft, .bottomLeft])
        }
        .applyIf(!isLandscape) { view in
            view.cornerRadiusLocal(24, corners: [.topLeft, .topRight])
        }
        .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: isLandscape ? 0 : -10)
        .onAppear {
            if hasShownPermissionPrompt {
                showPermissionView = false
                discoveryManager.startScanning()
            } else {
                showPermissionView = true
            }
        }
    }
    
    // MARK: - Permission Denied Content
    private var permissionDeniedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 60))
                .foregroundColor(.sheetTextDestructive)
                .padding(.top, 30)
            
            Text("Local Network Access Denied")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.sheetTextPrimary)
                .padding(.top, 10)
            
            Text("Please enable Local Network access in settings to discover casting devices.")
                .font(.system(size: 16))
                .foregroundColor(.themeSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.sheetTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.themeAccent)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Permission Content
    private var permissionContent: some View {
        VStack(spacing: 20) {
            Text("This app needs Local Network Access to Cast")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.sheetTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 20)
            
            Text("To connect to your devices, this app needs access to your Wi-Fi network.")
                .font(.system(size: 16))
                .foregroundColor(.themeSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("To Cast, select \"OK\" when the app asks to connect to your local network. You can also allow this later in iOS Settings for this app.")
                .font(.system(size: 16))
                .foregroundColor(.themeSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            
            Button(action: {
                hasShownPermissionPrompt = true
                withAnimation {
                    showPermissionView = false
                    discoveryManager.startScanning()
                }
            }) {
                Text("OK")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.sheetTextPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.themeAccent)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 15)
            
            Button(action: {
                if let url = URL(string: "https://support.google.com/chromecast/answer/10063094") {
                    openURL(url)
                }
            }) {
                Text("Learn more")
                    .font(.system(size: 16))
                    .foregroundColor(.themeAccent)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Discovery Content
    private var discoveryContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Top info card - fixed height
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.premiumCardBackground)
                        .frame(height: 140)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "tv.and.mediabox.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white.opacity(0.2))
                        
                        Text("Make sure your phone and TV are connected to the same WiFi network.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.premiumCardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                // Show loader while scanning
                if discoveryManager.isScanning {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .sheetTextPrimary))
                            .scaleEffect(1.5)
                        
                        Text("Searching...")
                            .foregroundColor(.sheetTextPrimary)
                            .font(.system(size: 16, weight: .medium))
                    }
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                }
                
                // Device list or no devices message
                if !discoveryManager.isScanning {
                    if discoveryManager.discoveredDevices.isEmpty {
                        noDevicesFooter
                    } else {
                        deviceList
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
    }
    
    private var deviceList: some View {
        VStack(spacing: 12) {
            ForEach(discoveryManager.discoveredDevices) { device in
                Button(action: {
                    // Handle device selection
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: device.type == .chromecast ? "tv" : "airplayvideo")
                            .foregroundColor(.sheetTextPrimary)
                            .font(.system(size: 22))
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.sheetTextPrimary)
                            Text(device.model)
                                .font(.system(size: 14))
                                .foregroundColor(.themeSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.themeSecondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(height: 70)
                    .background(Color.premiumCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.premiumCardBorder, lineWidth: 1)
                    )
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private var noDevicesFooter: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tv.and.mediabox")
                    .foregroundColor(.homeAccent)
                Text("No Cast devices are found")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.homeAccent)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Allow Local Network access in your phone settings.")
                    .font(.system(size: 13))
                    .foregroundColor(.homeAccent.opacity(0.8))
                Text("• Try restarting your Wi-Fi router or casting device.")
                    .font(.system(size: 13))
                    .foregroundColor(.homeAccent.opacity(0.8))
            }
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Settings")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.themeAccent)
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}
