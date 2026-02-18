import SwiftUI
import AVKit

struct ConflictResolutionView: View {
    @ObservedObject var viewModel: DashboardViewModel
    let conflict: DashboardViewModel.ConflictItem
    
    @State private var applyToAll: Bool = false
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            Text("File Conflict")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            // Card Content
            VStack(spacing: 16) {
                // Thumbnail & Info
                HStack(spacing: 16) {
                    // Thumbnail
                    ZStack {
                        if let thumb = thumbnail {
                            Image(uiImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .overlay(
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white.opacity(0.5))
                                )
                        }
                    }
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .clipped()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conflict.sourceTitle)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                        
                        if let duration = conflict.sourceDuration {
                            Text("Duration: \(duration)")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Text(conflict.formattedSize)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.premiumCardBackground)
                .cornerRadius(12)
                
                Text(conflict.message)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Apply to all
            if viewModel.conflictQueue.count > 1 {
                Button(action: {
                    HapticsManager.shared.generate(.selection)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        applyToAll.toggle()
                    }
                }) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                            
                            if applyToAll {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue)
                                    .frame(width: 22, height: 22)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Text("Apply to all remaining conflicts")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }
            
            // Actions
            VStack(spacing: 12) {
                Button(action: {
                    viewModel.resolveConflict(action: .keepBoth, applyToAll: applyToAll)
                }) {
                    Text("Keep Both")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                
                // Hide Replace option for Gallery operations (destructive)
                if conflict.destinationAlbum == nil {
                    Button(action: {
                        viewModel.resolveConflict(action: .replace, applyToAll: applyToAll)
                    }) {
                        Text("Replace")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                
                Button(action: {
                    viewModel.resolveConflict(action: .skip, applyToAll: applyToAll)
                }) {
                    Text("Skip")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
        }
        .padding(24)
        .background(
            AppGlobalBackground().ignoresSafeArea()
        )
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.premiumCardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 400)
        .padding(.horizontal, 20)
        .task(id: conflict.id) {
            // Load thumbnail
            self.thumbnail = nil
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        // Try to get thumbnail from VideoItem if available (Paste/Move)
        if let video = conflict.sourceVideo,
           let thumbPath = video.thumbnailPath,
           let image = UIImage(contentsOfFile: thumbPath.path) {
            self.thumbnail = image
            return
        }
        
        // Fallback generation from URL (Import)
        if let url = conflict.sourceURL ?? conflict.sourceVideo?.url {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            do {
                let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
                self.thumbnail = UIImage(cgImage: cgImage)
            } catch {
                print("Thumbnail gen failed: \(error)")
            }
        }
    }
}
