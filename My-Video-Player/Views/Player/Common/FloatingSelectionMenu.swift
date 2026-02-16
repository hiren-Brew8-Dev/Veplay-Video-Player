import SwiftUI

struct FloatingSelectionMenu<T: Hashable>: View {
    let title: String
    let items: [T]
    let selectedItem: T
    let itemLabel: (T) -> String
    let onSelect: (T) -> Void
    let onClose: () -> Void
    
    var body: some View {
        ZStack {
            // Background dimming
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    HapticsManager.shared.generate(.medium)
                    onClose()
                }
            
            // Menu Content
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        HapticsManager.shared.generate(.medium)
                        onClose()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding()
                .background(Color.white.opacity(0.1))
                
                Divider()
                    .background(Color.white.opacity(0.2))
                
                // Items List
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                            Button(action: {
                                HapticsManager.shared.generate(.selection)
                                onSelect(item)
                            }) {
                                HStack {
                                    Text(itemLabel(item))
                                        .font(.system(size: 16))
                                        .foregroundColor(item == selectedItem ? .homeAccent : .white)
                                    
                                    Spacer()
                                    
                                    if item == selectedItem {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.homeAccent)
                                    }
                                }
                                .padding()
                                .background(Color.black.opacity(0.001)) // Capture touches
                            }
                            
                            if index < items.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading)
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)))
            .cornerRadius(16)
            .padding(.horizontal, 40)
            .shadow(radius: 20)
            .frame(maxWidth: 400) // Constrain width on iPad/Landscape
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .zIndex(100) // Ensure it floats above everything
    }
}
