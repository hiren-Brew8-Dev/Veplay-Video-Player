import SwiftUI

struct AddVideoRowView: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.homeCardBackground)
                        .frame(width: 100, height: 60)
                    
                    Image(systemName: "plus")
                        .appIconStyle(size: AppDesign.Icons.selectionIconSize, weight: .bold, color: .homeAccent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import New")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.homeTextPrimary)
                    
                    Text("From Photos or Files")
                        .font(.system(size: 12))
                        .foregroundColor(.homeTextSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .appSecondaryIconStyle(size: 14, weight: .bold, color: .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.homeCardBackground.opacity(0.3))
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.scalable)
    }
}
