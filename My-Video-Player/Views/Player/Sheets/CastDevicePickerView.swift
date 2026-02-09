import SwiftUI

struct CastDevicePickerView: View {
    @ObservedObject var discoveryManager = DiscoveryManager()
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    let isLandscape: Bool
    var onBack: () -> Void
    
    @State private var showPermissionView = true // Should be driven by discoveryManager.needsPermission
    
    var body: some View {
        VStack(spacing: 0) {
            if showPermissionView {
                permissionView
            } else if discoveryManager.permissionDenied {
                permissionDeniedView
            } else {
                discoveryView
            }
        }
        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)))
    }
    
    // MARK: - Permission Denied View
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding()
            
            Spacer()
            
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("Local Network Access Denied")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            Text("Please enable Local Network access in settings to discover casting devices.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Open Settings")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
    }
    
    // MARK: - Permission View
    private var permissionView: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: { onBack() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .padding()
                }
            }
            
            Spacer()
            
            Text("This app needs Local Network Access to Cast")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("To connect to your devices, this app needs access to your Wi-Fi network.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("To Cast, select \"OK\" when the app asks to connect to your local network. You can also allow this later in iOS Settings for this app.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    showPermissionView = false
                    discoveryManager.startScanning()
                }
            }) {
                Text("OK")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            
            Button(action: {
                if let url = URL(string: "https://support.google.com/chromecast/answer/10063094") {
                    openURL(url)
                }
            }) {
                Text("Learn more")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Discovery View
    private var discoveryView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text("Device List")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Placeholder for symmetry
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.clear)
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Illustration placeholder (Image from user)
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 180)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "tv.and.mediabox.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("Make sure your phone and TV are connected to the same WiFi network.")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    .padding(.horizontal)
                    
                    if discoveryManager.isScanning {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            
                            Text("Loading...")
                                .foregroundColor(.white)
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
            }
            
            Spacer()
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
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                            Text(device.model)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
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
                    .foregroundColor(.orange)
                Text("No Cast devices are found")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• Allow Local Network access in your phone settings.")
                    .font(.system(size: 13))
                    .foregroundColor(.orange.opacity(0.8))
                Text("• Try restarting your Wi-Fi router or casting device.")
                    .font(.system(size: 13))
                    .foregroundColor(.orange.opacity(0.8))
            }
            
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("Settings")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
