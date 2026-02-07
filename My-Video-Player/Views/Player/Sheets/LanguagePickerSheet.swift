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
                    .foregroundColor(.homeTextPrimary)
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .foregroundColor(.homeAccent)
            }
            .padding()
            .background(Color.sheetSurface)
            
            // Search Bar (Visual only for now)
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.homeTextSecondary)
                Text("Search").foregroundColor(.homeTextSecondary)
                Spacer()
            }
            .padding(10)
            .background(Color.homeCardBackground)
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
                                    .foregroundColor(.homeTextPrimary)
                                    .font(.system(size: 16))
                                Spacer()
                                if selectedLanguageCode == lang.1 {
                                    Circle()
                                        .fill(Color.homeAccent)
                                        .frame(width: 8, height: 8)
                                } else {
                                    Circle()
                                        .fill(Color.sheetDivider)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding()
                            .background(Color.sheetBackground) // List item bg
                        }
                    }
                }
            }
        }
        .background(Color.sheetBackground.edgesIgnoringSafeArea(.all))
    }
}
