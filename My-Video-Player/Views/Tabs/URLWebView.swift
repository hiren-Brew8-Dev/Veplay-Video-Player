import Foundation
import SwiftUI
import WebKit

struct URLWebView: View {
    
    var titleName: String = "Privacy Policy"
    var urlString: String = "https://sites.google.com/view/shivshankarapps/privacy-policy"
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (Matching SettingsView style)
            HStack(spacing: 12) {
                Button(action: {
                    dismiss()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.premiumCircleBackground)
                            .frame(width: AppDesign.Icons.circleButtonSize, height: AppDesign.Icons.circleButtonSize)
                        
                        Image(systemName: "chevron.left")
                            .font(.system(size: isIpad ? 22 : 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text(titleName)
                    .font(.system(size: isIpad ? 32 : 18, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
                    .padding(.leading, 8)
                
                Spacer()
            }
            .padding(.horizontal, AppDesign.Icons.horizontalPadding)
            .padding(.vertical, isIpad ? 24 : 8)
            .background(Color.homeBackground)

            WebView(urlString: urlString)
                .ignoresSafeArea(edges: .bottom)
        }
        .background(Color.homeBackground.edgesIgnoringSafeArea(.all))
    }
}

struct WebView: UIViewRepresentable {
    let urlString: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.bounces = false
        webView.backgroundColor = .clear
        webView.isOpaque = false
        
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

#Preview {
    URLWebView()
}
