import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search videos..."
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.homeTextPrimary)
            
            if !text.isEmpty {
                Button(action: {
                    HapticsManager.shared.generate(.light)
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.homeTextSecondary)
                }
            }
        }
        .padding(10)
        .background(Color.homeCardBackground)
        .cornerRadius(10)
    }
}
