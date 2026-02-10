import SwiftUI

struct AddVideoRowView: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 100, height: 62)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.homeAccent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import New")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.homeTextPrimary)
                    
                    Text("From Photos or Files")
                        .font(.system(size: 12))
                        .foregroundColor(.homeTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.homeTextSecondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
