import SwiftUI

struct SeekIndicatorView: View {
    let isForward: Bool
    let amount: Double
    
    private var formattedAmount: String {
        let total = Int(amount)
        let m = total / 60
        let s = total % 60
        let timeStr = String(format: "%02d:%02d", m, s)
        let prefix = isForward ? "" : "-"
        return "\(prefix)\(timeStr) mins"
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isForward ? "goforward" : "gobackward")
                .font(.system(size: 30))
            
            Text(formattedAmount)
                .font(.system(size: 24, weight: .bold))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
        .foregroundColor(.white)
    }
}
