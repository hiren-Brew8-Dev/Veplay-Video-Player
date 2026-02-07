import SwiftUI
import UniformTypeIdentifiers

struct AudioCaptionsSheet: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool
    let isLandscape: Bool
    var onBack: (() -> Void)?
    
    @State private var showingFileImporter = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            Capsule()
                .fill(Color.homeTextSecondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)
            
            // Header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.homeTextPrimary)
                        .padding(10)
                }
                
                Spacer()
                
                Text("Audio & CC")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Invisible spacer to balance
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.clear)
                    .padding(10)
            }
            .padding(.horizontal, isLandscape ? 40 : 20)
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.bottom, 16)
            
            // Content - Side by side in landscape, top-bottom in portrait
            if isLandscape {
                HStack(spacing: 0) {
                    // Audio Section
                    audioSection
                        .frame(maxWidth: .infinity)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    // Captions Section
                    captionsSection
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 40) // Added padding for full screen look spacing
            } else {
                VStack(spacing: 0) {
                    // Audio Section
                    audioSection
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.vertical, 16)
                    
                    // Captions Section
                    captionsSection
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding(.bottom, isLandscape ? 20 : 40) // Respect safe area
        .background(Color.sheetBackground)
        .cornerRadiusLocal(20, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: -5)
    }
    
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text("Audio Track")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 4) // Tightening internal spacing to let container handle edges
            
            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.availableAudioTracks.isEmpty {
                        // Off option when no tracks
                        Button(action: {
                            // Already effectively off or single track? Usually 0 is the only option.
                            // For consistency showing an Off state if requested.
                        }) {
                            HStack {
                                Text("No Audio")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.red)
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.homeAccent.opacity(0.15))
                        }
                        .buttonStyle(.plain)
                    } else {
                        ForEach(Array(viewModel.availableAudioTracks.enumerated()), id: \.offset) { index, track in
                            Button(action: {
                                viewModel.selectAudioTrack(at: index)
                            }) {
                                HStack {
                                    Text(track)
                                        .font(.system(size: 15))
                                        .foregroundColor(.homeTextPrimary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if index == viewModel.selectedAudioTrackIndex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.homeAccent)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(index == viewModel.selectedAudioTrackIndex ? Color.homeAccent.opacity(0.15) : Color.clear)
                            }
                            .buttonStyle(.plain)
                            
                            if index < viewModel.availableAudioTracks.count - 1 {
                                Divider()
                                    .background(Color.sheetDivider)
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            
            Divider()
                .background(Color.sheetDivider)
                .padding(.vertical, 8)
            
            // Audio Delay Control
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Text("Audio Delay")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.2fs", viewModel.audioDelay))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.homeAccent)
                        .monospacedDigit()
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.audioDelay -= 0.05
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.homeTextPrimary)
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Slider(value: $viewModel.audioDelay, in: -5.0...5.0, step: 0.05)
                        .accentColor(.homeAccent)
                    
                    Button(action: {
                        viewModel.audioDelay += 0.05
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.gray.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical)
    }
    
    private var captionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "captions.bubble.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                Text("Subtitles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showingFileImporter = true }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 18))
                        .foregroundColor(.white)
                        .padding(4)
                }
            }
            .padding(.horizontal, 4) // Tightening internal spacing
            
            ScrollView {
                VStack(spacing: 0) {
                    // Off option
                    Button(action: {
                        viewModel.selectSubtitleTrack(at: -1)
                    }) {
                        HStack {
                            Text("Off")
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if !viewModel.subtitleManager.isEnabled {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.red)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(!viewModel.subtitleManager.isEnabled ? Color.homeAccent.opacity(0.15) : Color.clear)
                    }
                    .buttonStyle(.plain)
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.leading, 16)
                    
                    // Available subtitles
                    ForEach(Array(viewModel.subtitleManager.availableTracks.enumerated()), id: \.offset) { index, subtitle in
                        Button(action: {
                            viewModel.selectSubtitleTrack(at: index)
                        }) {
                            HStack {
                                Text(subtitle.name) // Use .name from SubtitleTrack
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                if viewModel.subtitleManager.isEnabled && viewModel.subtitleManager.selectedTrackIndex == index {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.homeAccent)
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background((viewModel.subtitleManager.isEnabled && viewModel.subtitleManager.selectedTrackIndex == index) ? Color.homeAccent.opacity(0.15) : Color.clear)
                        }
                        .buttonStyle(.plain)
                        
                        if index < viewModel.subtitleManager.availableTracks.count - 1 {
                            Divider()
                                .background(Color.sheetDivider)
                                .padding(.leading, 16)
                        }
                    }
                }
            }
        }
        .padding(.vertical)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType.plainText, UTType(filenameExtension: "srt")!, UTType.text],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                if url.startAccessingSecurityScopedResource() {
                    viewModel.subtitleManager.loadSubtitle(from: url)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }
}
