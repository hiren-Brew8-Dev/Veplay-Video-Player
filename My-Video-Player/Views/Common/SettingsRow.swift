import SwiftUI

struct SettingsRow<Destination: View>: View {
    let icon: String
    let title: String
    let destination: Destination
    var iconColor: Color = .blue
    
    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
                    .frame(width: 30) // Fixed width for alignment
                
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
}

// Overload for Toggles
struct SettingsToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool
    var iconColor: Color = .blue
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            Toggle(title, isOn: $isOn)
        }
        .padding(.vertical, 4)
    }
}
