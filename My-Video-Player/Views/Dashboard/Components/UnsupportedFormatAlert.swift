import SwiftUI
import AVFoundation
import Photos

struct UnsupportedFormatAlert: View {
    let video: VideoItem?
    @Binding var isPresented: Bool
    
    @State private var thumbImage: UIImage? = nil
    
    var body: some View {
        if let video = video {
            ZStack {
                // Background Dimming with Blur
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    .background(.ultraThinMaterial)
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
                
                VStack(spacing: 28) {
                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.red)
                    }
                    .padding(.top, 10)
                    
                    // Video Info Card
                    VStack(spacing: 16) {
                        ZStack(alignment: .bottomTrailing) {
                            if let thumb = thumbImage {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 160, height: 100)
                                    .cornerRadius(16)
                                    .clipped()
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 160, height: 100)
                                    
                                    Image(systemName: "video.fill")
                                        .foregroundColor(.white.opacity(0.2))
                                }
                            }
                            
                            // Duration Overlay
                            Text(video.formattedDuration)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                                .padding(6)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 15)
                        
                        VStack(spacing: 6) {
                            Text(video.title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 8) {
                                Text(video.url?.pathExtension.uppercased() ?? "MKV")
                                    .font(.system(size: 10, weight: .black))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                
                                Text("NOT SUPPORTED")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 10) {
                        Text("Compatibility Error")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("This video format is not supported for move or copy to gallery albums. Supported formats: MP4, MOV, M4V.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
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
                            .background(
                                LinearGradient(
                                    colors: [.orange, .orange.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(18)
                            .shadow(color: Color.orange.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
                }
                .padding(.vertical, 32)
                .background(
                    LinearGradient(
                        colors: [.premiumGradientTop, .premiumGradientBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(32)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color.premiumCardBorder, lineWidth: 1.5)
                )
                .padding(.horizontal, 32)
                .shadow(color: Color.black.opacity(0.5), radius: 30, x: 0, y: 15)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .center)))
            .zIndex(500)
            .onAppear {
                loadThumbnail()
            }
        }
    }
    
    private func loadThumbnail() {
        guard let video = video else { return }
        ThumbnailCacheManager.shared.getThumbnail(for: video) { image in
            self.thumbImage = image
        }
    }
}
