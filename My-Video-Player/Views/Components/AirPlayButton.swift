import SwiftUI
import AVKit

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.backgroundColor = .clear
        routePickerView.activeTintColor = .systemBlue
        routePickerView.tintColor = .white
        // This ensures the button is visible even if no routes are "customarily" available, 
        // though typically it hides if no routes.
        // prioritized for video
        routePickerView.prioritizesVideoDevices = true 
        return routePickerView
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // No updates needed
    }
}
