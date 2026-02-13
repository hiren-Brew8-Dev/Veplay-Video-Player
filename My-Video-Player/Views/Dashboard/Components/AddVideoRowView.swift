import SwiftUI

struct AddVideoRowView: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: isIpad ? 140 : 96, height: isIpad ? 100 : 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    Image(systemName: "plus")
                        .font(.system(size: isIpad ? 30 : 24, weight: .bold))
                        .foregroundColor(.homeAccent)
                }
                
                VStack(alignment: .leading, spacing: isIpad ? 8 : 4) {
                    Text("Import New")
                        .font(.system(size: isIpad ? 22 : 16, weight: .semibold))
                        .foregroundColor(.homeTextPrimary)
                    
                    Text("From Photos or Files")
                        .font(.system(size: isIpad ? 16 : 12))
                        .foregroundColor(.homeTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: isIpad ? 18 : 14, weight: .bold))
                    .foregroundColor(.homeTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, AppDesign.Icons.horizontalPadding)
            .padding(.vertical, 10)
            .background(Color.homeBackground.opacity(0.001))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
