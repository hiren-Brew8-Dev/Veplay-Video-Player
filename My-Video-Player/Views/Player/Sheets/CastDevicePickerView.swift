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
            if showPermissionView && !hasShownPermissionPrompt {
                permissionView
            } else if discoveryManager.permissionDenied {
                permissionDeniedView
            } else {
                discoveryView
            }
        }
        .background(Color.sheetBackground)
        .onAppear {
            // If we've already shown the permission prompt before, skip to discovery
            if hasShownPermissionPrompt {
                showPermissionView = false
                discoveryManager.startScanning()
            } else {
                showPermissionView = true
            }
        }
    }
    
    // MARK: - Permission Denied View
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: { onBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.sheetTextPrimary)
                        .padding(10)
                }
                Spacer()
            }
            .padding(.horizontal)
            
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
    
    // MARK: - Permission View
    private var permissionView: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: { onBack() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.sheetTextPrimary)
                        .padding()
                }
            }
            
            Text("This app needs Local Network Access to Cast")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.sheetTextPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
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
                .padding(.bottom, 30)
            
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
            .padding(.bottom, 20)
            
            Button(action: {
                if let url = URL(string: "https://support.google.com/chromecast/answer/10063094") {
                    openURL(url)
                }
            }) {
                Text("Learn more")
                    .font(.system(size: 16))
                    .foregroundColor(.themeAccent)
            }
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Discovery View
    private var discoveryView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.sheetTextPrimary)
                        .padding(10)
                }
                
                Spacer()
                
                Text("Device List")
                    .font(.headline)
                    .foregroundColor(.sheetTextPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.clear)
                    .padding(10)
            }
            .padding(.horizontal)
            
            Divider()
                .background(Color.sheetDivider)
            
            ScrollView {
                VStack(spacing: 20) {
                    // Illustration placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.sheetSurface)
                            .frame(height: 150)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "tv.and.mediabox.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.themeSecondary)
                            
                            Text("Make sure your phone and TV are connected to the same WiFi network.")
                                .font(.system(size: 14))
                                .foregroundColor(.themeSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .padding(.horizontal)
                    
                    if discoveryManager.isScanning {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .sheetTextPrimary))
                                .scaleEffect(1.5)
                            
                            Text("Loading...")
                                .foregroundColor(.sheetTextPrimary)
                                .font(.system(size: 16))
                        }
                        .frame(height: 100)
                    } else if discoveryManager.discoveredDevices.isEmpty {
                        noDevicesFooter
                    } else {
                        deviceList
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
        }
    }
    
    private var deviceList: some View {
        VStack(spacing: 0) {
            ForEach(discoveryManager.discoveredDevices) { device in
                Button(action: {
                    // Handle device selection
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "airplayvideo")
                            .foregroundColor(.sheetTextPrimary)
                            .font(.system(size: 20))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.sheetTextPrimary)
                            Text(device.model)
                                .font(.system(size: 14))
                                .foregroundColor(.themeSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.sheetSurface)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
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
        .padding()
        .background(Color.homeAccent.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
