import SwiftUI
import AVFoundation
import AVKit

struct CastButton: View {
    @ObservedObject var viewModel: PlayerViewModel
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "airplayvideo")
                .font(.system(size: 20))
                .foregroundColor(viewModel.isExternalPlaybackActive ? .blue : .white)
        }
        .frame(width: 40, height: 44)
    }
}

// Native route picker that triggers on tap
struct AVRoutePickerViewWrapper: UIViewRepresentable {
    let isActive: Bool
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = .white
        picker.tintColor = .white
        picker.prioritizesVideoDevices = true
        
        // Customize button appearance
        if let button = picker.subviews.first(where: { $0 is UIButton }) as? UIButton {
            button.tintColor = .white
        }
        
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // Update tint color based on active state
        uiView.activeTintColor = isActive ? UIColor.systemBlue : UIColor.white
        
        // Add blue indicator when casting
        if isActive {
            // The native picker already shows active state, but we can enhance it
            uiView.tintColor = UIColor.systemBlue
        } else {
            uiView.tintColor = UIColor.white
        }
    }
}

// Direct route picker sheet (kept for backward compatibility but not used)
struct RoutePickerSheet: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Text("Select Device")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .foregroundColor(.blue)
            }
            .padding()
            
            AirPlayPickerWrapper(tintColor: .white)
                .frame(height: 60)
                .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)))
        .presentationDetents([.medium])
    }
}
