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
                    HapticsManager.shared.generate(.medium)
                    isPresented = false
                }
                .foregroundColor(.homeAccent)
            }
            .padding()
            .background(Color.premiumCardBackground)
            
            // Search Bar (Visual only for now)
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.homeTextSecondary)
                Text("Search").foregroundColor(.homeTextSecondary)
                Spacer()
            }
            .padding(10)
            .background(Color.premiumCardBackground)
            .cornerRadius(8)
            .padding()
            
            // List
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(languages, id: \.1) { lang in
                        Button(action: {
                            HapticsManager.shared.generate(.selection)
                            selectedLanguageCode = lang.1
                            isPresented = false
                        }) {
                            HStack {
                                Text(lang.0)
                                    .foregroundColor(.white) // Ensure text is white
                                    .font(.system(size: 16))
                                Spacer()
                                if selectedLanguageCode == lang.1 {
                                    Circle()
                                        .fill(Color.homeAccent)
                                        .frame(width: 8, height: 8)
                                } else {
                                    Circle()
                                        .fill(Color.white.opacity(0.3)) // Lighter divider
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding()
                            .background(Color.clear) // Transparent list item bg
                        }
                    }
                }
            }
        }
        .background(
            AppGlobalBackground().ignoresSafeArea()
        )
        .applyIf(isIpad) { $0.cornerRadius(28) }
        .shadow(color: isIpad ? Color.black.opacity(0.5) : .clear, radius: isIpad ? 20 : 0)
    }
}
