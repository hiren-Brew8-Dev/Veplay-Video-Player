import SwiftUI

struct UnsupportedFormatAlert: View {
    let video: VideoItem?
    @Binding var isPresented: Bool
    
    var body: some View {
        if let video = video {
            ZStack {
                // Background Dimming
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
                
                VStack(spacing: 24) {
                    // Header with Icon
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.top, 10)
                    
                    // Thumbnail & Info Card
                    VStack(spacing: 12) {
                        if let thumbPath = video.thumbnailPath {
                            Image(uiImage: UIImage(contentsOfFile: thumbPath.path) ?? UIImage())
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 80)
                                .cornerRadius(12)
                                .clipped()
                                .shadow(radius: 5)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.homeCardBackground)
                                    .frame(width: 120, height: 80)
                                
                                Image(systemName: "video.fill")
                                    .foregroundColor(.homeTextSecondary)
                            }
                        }
                        
                        Text(video.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.homeTextPrimary)
                            .lineLimit(1)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 6) {
                            Text(video.url?.pathExtension.uppercased() ?? "VAR")
                                .font(.system(size: 10, weight: .black))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            
                            Text("NOT SUPPORTED")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        Text("Compatibility Error")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.homeTextPrimary)
                        
                        Text("This video format is not supported for move or copy to gallery albums. Supported formats: MP4, MOV, M4V.")
                            .font(.system(size: 14))
                            .foregroundColor(.homeTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    
                    // Action Button
                    Button(action: {
                        withAnimation {
                            isPresented = false
                        }
                    }) {
                        Text("Got it")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.homeAccent)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
                }
                .padding(.vertical, 30)
                .background(Color.sheetSurface)
                .cornerRadius(32)
                .padding(.horizontal, 30)
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .center)))
            .zIndex(500)
        }
    }
}
