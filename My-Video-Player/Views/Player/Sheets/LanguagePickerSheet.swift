import SwiftUI

struct LanguagePickerSheet: View {
    @Binding var selectedLanguageCode: String
    @Binding var isPresented: Bool
    
    let languages = [
        ("English", "en"),
        ("Hindi", "hi"),
        ("Spanish", "es"),
        ("French", "fr"),
        ("German", "de"),
        ("Italian", "it"),
        ("Chinese", "zh"),
        ("Malay", "ms"),
        ("Arabic", "ar"),
        ("Portuguese", "pt"),
        ("Russian", "ru"),
        ("Japanese", "ja")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Select Language")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color(UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)))
            
            // Search Bar (Visual only for now)
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.gray)
                Text("Search").foregroundColor(.gray)
                Spacer()
            }
            .padding(10)
            .background(Color(UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)))
            .cornerRadius(8)
            .padding()
            
            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(languages, id: \.1) { lang in
                        Button(action: {
                            selectedLanguageCode = lang.1
                            isPresented = false
                        }) {
                            HStack {
                                Text(lang.0)
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                                Spacer()
                                if selectedLanguageCode == lang.1 {
                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 8, height: 8)
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding()
                            .background(Color.black) // List item bg
                        }
                    }
                }
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
