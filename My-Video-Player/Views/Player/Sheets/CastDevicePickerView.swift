import SwiftUI
import AVKit
import GoogleCast

struct CastDevicePickerView: View {
    @ObservedObject var castManager = GoogleCastManager.shared
    // We can keep DiscoveryManager for AirPlay custom discovery if we wanted, 
    // but we use the system button now. So we can remove it or keep it for checking permissions.
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
            if !isLandscape && !isIpad {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            
            // Header
            HStack {
                Button(action: {
                    HapticsManager.shared.generate(.medium)
                    onBack()
                }) {
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
            .padding(.top, (isLandscape || isIpad) ? 16 : 0)
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
        .applyIf(isLandscape && !isIpad) { $0.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top) }
        .applyIf(!isLandscape && !isIpad) { $0.padding(.bottom, 20) }
        .background(
            AppGlobalBackground().ignoresSafeArea()
        )
        .applyIf(isIpad) { $0.cornerRadius(28) }
        .applyIf(isLandscape && !isIpad) { view in
            view.cornerRadiusLocal(24, corners: [.topLeft, .bottomLeft])
        }
        .applyIf(!isLandscape && !isIpad) { view in
            view.cornerRadiusLocal(24, corners: [.topLeft, .topRight])
        }
        .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: (isLandscape || isIpad) ? 10 : -10)
        .onAppear {
            castManager.startDiscovery()
            if hasShownPermissionPrompt {
                showPermissionView = false
                discoveryManager.startScanning() 
            } else {
                showPermissionView = true
            }
        }
        .onDisappear {
            castManager.stopDiscovery()
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
                HapticsManager.shared.generate(.medium)
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
                HapticsManager.shared.generate(.medium)
                hasShownPermissionPrompt = true
                withAnimation {
                    showPermissionView = false
                    castManager.startDiscovery()
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
                HapticsManager.shared.generate(.light)
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
        ScrollView(showsIndicators: false) {
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
                
                airPlaySection
                
                // Device list or no devices message
                // We now check castManager.devices instead of discoveryManager.discoveredDevices for Chromecast
                if castManager.devices.isEmpty {
                    noDevicesFooter
                } else {
                    deviceList
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
    
    private var deviceList: some View {
        VStack(spacing: 12) {
            ForEach(castManager.devices, id: \.deviceID) { device in
                Button(action: {
                    HapticsManager.shared.generate(.selection)
                    castManager.connect(to: device)
                    dismiss()
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: "tv")
                            .foregroundColor(.sheetTextPrimary)
                            .font(.system(size: 22))
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.friendlyName ?? "Google Cast Device")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.sheetTextPrimary)
                            Text(device.modelName ?? "Chromecast")
                                .font(.system(size: 14))
                                .foregroundColor(.themeSecondary)
                        }
                        
                        Spacer()
                        
                        if castManager.isConnected && castManager.currentSession?.device.deviceID == device.deviceID {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.themeSecondary)
                        }
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
    
    // MARK: - AirPlay Section
    private var airPlaySection: some View {
        ZStack {
             HStack(spacing: 16) {
                // Static Icon on left
                Image(systemName: "airplayvideo")
                    .foregroundColor(.sheetTextPrimary)
                    .font(.system(size: 22))
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("AirPlay & Bluetooth")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.sheetTextPrimary)
                    Text("Tap icon to connect")
                        .font(.system(size: 14))
                        .foregroundColor(.themeSecondary)
                }
                
                Spacer()
                
                // The Helper Arrow to suggest clicking
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.themeSecondary)
                    .padding(.trailing, 8)
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
            
            // The Actual AVRoutePickerView overlaid on top but invisible/transparent
            // effectively making the whole card a trigger for the system picker
            AirPlayButton()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // We use a custom coordinator or just let it handle touches.
                // Note: AVRoutePickerView usually draws the icon. 
                // To make a custom UI trigger it, we layer it on top with opacity 0.01
                .opacity(0.02) 
        }
        .padding(.horizontal, 20)
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
                Text("• Allow Local Network access in your phone settings.")
                    .font(.system(size: 13))
                    .foregroundColor(.homeAccent.opacity(0.8))
                Text("• For Mac/Apple TV, use the AirPlay option above.")
                    .font(.system(size: 13))
                    .foregroundColor(.homeAccent.opacity(0.8))
                Text("• Try restarting your Wi-Fi router or casting device.")
                    .font(.system(size: 13))
                    .foregroundColor(.homeAccent.opacity(0.8))
            }
            
            Button(action: {
                HapticsManager.shared.generate(.medium)
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
