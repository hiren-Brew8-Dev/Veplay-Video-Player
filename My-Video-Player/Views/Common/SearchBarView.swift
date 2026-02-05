import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search videos..."
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(red: 0.15, green: 0.15, blue: 0.18))
        .cornerRadius(10)
    }
}
