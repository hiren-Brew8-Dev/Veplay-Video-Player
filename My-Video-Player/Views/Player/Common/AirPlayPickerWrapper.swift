import SwiftUI
import AVKit

struct AirPlayPickerWrapper: UIViewRepresentable {
    var tintColor: Color = .white
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.activeTintColor = UIColor(tintColor)
        picker.tintColor = UIColor(tintColor.opacity(0.6))
        picker.prioritizesVideoDevices = true
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.activeTintColor = UIColor(tintColor)
        uiView.tintColor = UIColor(tintColor.opacity(0.6))
    }
}
