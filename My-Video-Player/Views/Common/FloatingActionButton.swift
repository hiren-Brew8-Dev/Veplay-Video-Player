import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.orange)
                .cornerRadius(28)
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
        }
    }
}
