import SwiftUI
import AVKit

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
    @State private var airPlayTrigger: Int = 0
    
    var body: some View {
        ZStack {
            // Base sheet - Select Device (always present)
            mainLayout
                .opacity(showDiscovery ? 0 : 1)
                .allowsHitTesting(!showDiscovery)
            
            // Overlay sheet - Device List (appears on top)
            if showDiscovery {
                GeometryReader { geometry in
                    CastDevicePickerView(
                        isLandscape: isLandscape,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showDiscovery = false
                            }
                        }
                    )
                    .applyIf(!isLandscape) { view in
                        view.frame(height: geometry.size.height * 0.5)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .transition(.move(edge: isLandscape ? .trailing : .bottom))
                }
                .zIndex(1)
            }

            // Hidden route picker used for programmatic open from the row button.
            ProgrammaticAirPlayPicker(trigger: $airPlayTrigger)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
        }
    }
    
    private var mainLayout: some View {
        VStack(spacing: 0) {
            // Drag Handle
            if !isLandscape && !isIpad {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            
            header
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    optionsCard
                }
                .padding(.horizontal, isIpad ? 32 : 20)
                .padding(.bottom, isIpad ? 40 : 30)
            }
        }
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
    }

    private var header: some View {
        HStack {
            Button(action: {
                HapticsManager.shared.generate(.medium)
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPresented = false
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.premiumCircleBackground)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Select Device")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            // Invisible spacer to balance
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, isLandscape ? 16 : 0)
        .padding(.bottom, 20)
    }

    private var optionsCard: some View {
        VStack(spacing: 0) {
            castingOptionItem(title: "AirPlay & Bluetooth", icon: "airplayvideo", action: {
                HapticsManager.shared.generate(.selection)
                airPlayTrigger += 1
            })
            divider
            castingOptionItem(title: "Casting Device", icon: "airplayvideo", action: {
                HapticsManager.shared.generate(.selection)
                withAnimation(.easeInOut(duration: 0.3)) {
                    showDiscovery = true
                }
            })
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.premiumCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.premiumCardBorder, lineWidth: 1)
        )
    }

    private func castingOptionItem(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.premiumCircleBackground)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.premiumCardBorder) // Changed from premiumCardBackground for visibility
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}

private struct ProgrammaticAirPlayPicker: UIViewRepresentable {
    @Binding var trigger: Int
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .white
        picker.tintColor = .clear
        picker.prioritizesVideoDevices = true
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        guard context.coordinator.lastTrigger != trigger else { return }
        context.coordinator.lastTrigger = trigger
        
        // AVRoutePickerView embeds a UIButton; trigger it programmatically.
        if let button = uiView.subviews.first(where: { $0 is UIButton }) as? UIButton {
            button.sendActions(for: .touchUpInside)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator {
        var lastTrigger: Int = 0
    }
}
