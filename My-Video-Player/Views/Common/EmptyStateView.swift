import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .appSecondaryIconStyle(size: isIpad ? 80 : 50, color: .homeTextSecondary)
            Text(message)
                .font(.system(size: isIpad ? 24 : 17, weight: .semibold))
                .foregroundColor(.homeTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
