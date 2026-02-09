import SwiftUI

struct CastingModeSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool
    @Binding var selectedMode: CastingMode?
    let isLandscape: Bool
    
    enum CastingMode {
        case airplayBluetooth
        case castingDevice
    }
    
    @State private var showDiscovery = false
    
    var body: some View {
        ZStack {
            if showDiscovery {
                CastDevicePickerView(
                    isLandscape: isLandscape,
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showDiscovery = false
                        }
                    }
                )
            } else {
                mainLayout
            }
        }
    }
    
    private var mainLayout: some View {
        VStack(spacing: 0) {
            // Drag Handle (Always visible when bottom-to-top)
            Capsule()
                .fill(Color.sheetDivider)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 10)
            
            // Header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                }
                
                Spacer()
                
                Text("Select Device")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Invisible spacer for symmetry
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.clear)
                    .padding(10)
            }
            .padding(.horizontal)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            if isLandscape {
                landscapeContent
            } else {
                portraitContent
            }
        }
        .padding(.horizontal, isLandscape ? 20 : 0)
        .padding(.bottom, 15)
        .padding(.trailing, isLandscape ? 20 : 0)
        .background(Color.sheetBackground)
        .if(isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .bottomLeft])
        }
        .if(!isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .topRight])
        }
        .shadow(color: Color.black.opacity(0.5), radius: 10, x: isLandscape ? -5 : 0, y: isLandscape ? 0 : -5)
    }
    
    private var portraitContent: some View {
        VStack(spacing: 0) {
            // AirPlay row - Wrapped with RoutePickerViewWrapper for tap handling
            ZStack {
                HStack(spacing: 16) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 22))
                        .foregroundColor(.sheetTextPrimary)
                        .frame(width: 32)
                    
                    Text("AirPlay & Bluetooth")
                        .font(.system(size: 16))
                        .foregroundColor(.sheetTextPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.themeSecondary)
                }
                .padding(.horizontal, 20)
                .frame(height: 50)
                .contentShape(Rectangle())
                
                // Invisible route picker overlay to capture taps
                RoutePickerViewWrapper()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.011) // Nearly invisible but still tappable
            }
            
            Divider()
                .background(Color.sheetDivider)
                .padding(.leading, 68)
            
            // Cast row
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showDiscovery = true
                }
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "airplayvideo")
                        .font(.system(size: 22))
                        .foregroundColor(.sheetTextPrimary)
                        .frame(width: 32)
                    
                    Text("Casting Device")
                        .font(.system(size: 16))
                        .foregroundColor(.sheetTextPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.themeSecondary)
                }
                .padding(.horizontal, 20)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
        }
        .padding(.top, 5)
    }
    private var landscapeContent: some View {
        HStack(spacing: 20) {
            // AirPlay & BT
            ZStack {
                VStack(spacing: 8) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 24))
                        .foregroundColor(.sheetTextPrimary)
                    
                    Text("AirPlay & BT")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.sheetTextPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(Color.sheetSurface)
                .cornerRadius(12)
                
                RoutePickerViewWrapper()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.011) // Nearly invisible but still tappable
            }
            
            // Cast Device
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showDiscovery = true
                }
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "airplayvideo")
                        .font(.system(size: 24))
                        .foregroundColor(.sheetTextPrimary)
                    
                    Text("Cast Device")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.sheetTextPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 80)
                .background(Color.sheetSurface)
                .cornerRadius(12)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 10)
    }
}

// Helper for system route picker
import AVKit
struct RoutePickerViewWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .systemBlue
        picker.tintColor = .white
        picker.prioritizesVideoDevices = true
        
        // Make the picker button fill the entire view
        picker.isUserInteractionEnabled = true
        
        // Make the button inside the picker fully visible and tappable
        if let button = picker.subviews.first(where: { $0 is UIButton }) as? UIButton {
            button.isUserInteractionEnabled = true
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - PlayingModeSheet

struct PlayingModeSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool
    let isLandscape: Bool
    var onBack: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle (Portrait)
            if !isLandscape {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
            
            // Header
            HStack {
                StandardIconButton(icon: "chevron.left", action: {
                    if let back = onBack {
                        back()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                })
                
                Spacer()
                
                Text("Playing Mode")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                StandardIconButton(icon: "chevron.left", color: .clear, bg: .clear, action: {})
            }
            .padding(.horizontal)
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.bottom, 16)
            
            // Options
            VStack(spacing: 0) {
                playingModeRow(title: "Play in Order", icon: "list.bullet", mode: .playInOrder)
                Divider().background(Color.gray.opacity(0.2)).padding(.leading, 50)
                
                playingModeRow(title: "Shuffle Play", icon: "shuffle", mode: .shufflePlay)
                Divider().background(Color.gray.opacity(0.2)).padding(.leading, 50)
                
                playingModeRow(title: "Repeat Ones", icon: "repeat.1", mode: .repeatOne)
                Divider().background(Color.gray.opacity(0.2)).padding(.leading, 50)
                
                playingModeRow(title: "One Track", icon: "1.square", mode: .oneTrack)
            }
            .padding(.horizontal)
            
            Spacer()
            

        }
        .padding(.trailing, isLandscape ? 30 : 0)
        .background(Color(UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)))
        .if(isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .bottomLeft])
        }
        .if(!isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .topRight])
        }
    }
    
    func playingModeRow(title: String, icon: String, mode: PlayerViewModel.PlayingMode) -> some View {
        let isSelected = viewModel.playingMode == mode
        
        return Button(action: {
            viewModel.playingMode = mode
            withAnimation(.easeInOut(duration: 0.3)) {
                isPresented = false
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .orange : .white)
                .frame(width: 24)
                
                Text(title)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .orange : .white)
                
                Spacer()
            }
            .frame(height: 54)
            .contentShape(Rectangle())
        }
    }
    

}

// MARK: - PlaybackSpeedSheet

struct PlaybackSpeedSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool
    let isLandscape: Bool
    var onBack: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle (Portrait)
            if !isLandscape {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
            
            // Header
            HStack {
                StandardIconButton(icon: "chevron.left", action: {
                    if let back = onBack {
                        back()
                    } else {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }
                })
                
                Spacer()
                
                Text("Playback Speed")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                StandardIconButton(icon: "chevron.left", color: .clear, bg: .clear, action: {})
            }
            .padding(.horizontal)
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.bottom, 30)
            
            // Speed Display
            Text(String(format: "%g", viewModel.playbackSpeed) + "x")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 20)
            
            // Slider Control
            HStack(spacing: 20) {
                // Minus Button
                Button(action: {
                    updateSpeed(viewModel.playbackSpeed - 0.05)
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                // Slider
                // Slider
                CustomSlider(
                    value: Binding(
                        get: { Double(viewModel.playbackSpeed) },
                        set: { updateSpeed(Float($0)) }
                    ),
                    range: 0.25...2.0,
                    step: 0.05,
                    onEditingChanged: { _ in }
                )
                .frame(height: 20)
                
                // Plus Button
                Button(action: {
                    updateSpeed(viewModel.playbackSpeed + 0.05)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            
            // Presets
            HStack(spacing: 12) {
                ForEach([0.25, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                    speedPreset(Float(speed))
                }
            }
            .padding(.horizontal)
            
            Spacer()
            

        }
        .padding(.trailing, isLandscape ? 30 : 0)
        .background(Color(UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)))
        .if(isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .bottomLeft])
        }
        .if(!isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .topRight])
        }
    }
    
    func updateSpeed(_ speed: Float) {
        let clamped = min(max(speed, 0.25), 2.0)
        viewModel.setSpeed(clamped)
    }
    
    func speedPreset(_ speed: Float) -> some View {
        let isSelected = abs(viewModel.playbackSpeed - speed) < 0.01
        
        return Button(action: {
            viewModel.setSpeed(speed)
        }) {
            Text(String(format: "%g", speed))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .cornerRadius(18)
        }
    }
}
