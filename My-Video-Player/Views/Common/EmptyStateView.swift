import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .appSecondaryIconStyle(size: 50, color: .homeTextSecondary)
            Text(message)
                .font(.headline)
                .foregroundColor(.homeTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
