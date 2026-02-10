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
            if !isLandscape {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
            }
            
            // Header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.premiumCircleBackground)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Audio & CC")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Invisible spacer to balance
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, isLandscape ? 16 : 0)
            .padding(.bottom, 20)
            
            // Content
            if isLandscape {
                // Landscape: Side by side layout
                HStack(alignment: .top, spacing: 20) {
                    // Left Column: Audio Track + Audio Delay
                    VStack(spacing: 20) {
                        audioTrackSection
                        audioDelaySection
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Right Column: Subtitles
                    subtitlesSection
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            } else {
                // Portrait: Stacked layout
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Audio Track Section
                        audioTrackSection
                        
                        // Audio Delay Section
                        audioDelaySection
                        
                        // Subtitles Section
                        subtitlesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [.premiumGradientTop, .premiumGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadiusLocal(24, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.6), radius: 20, x: 0, y: -10)
    }
    
    // MARK: - Audio Track Section
    
    private var audioTrackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.homeAccent.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.homeAccent)
                }
                
                Text("Audio Track")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            // Track List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    if viewModel.availableAudioTracks.isEmpty {
                        audioTrackRow(title: "No Audio", isSelected: true, isDisabled: true)
                    } else {
                        ForEach(Array(viewModel.availableAudioTracks.enumerated()), id: \.offset) { index, track in
                            audioTrackRow(
                                title: track,
                                isSelected: index == viewModel.selectedAudioTrackIndex,
                                isDisabled: false
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectAudioTrack(at: index)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: isLandscape ? 200 : 300)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.premiumCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.premiumCardBorder, lineWidth: 1)
        )
    }
    
    private func audioTrackRow(title: String, isSelected: Bool, isDisabled: Bool, action: (() -> Void)? = nil) -> some View {
        Button(action: {
            action?()
        }) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    .lineLimit(1)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isDisabled ? .red : .homeAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.homeAccent.opacity(0.15) : Color.premiumCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.homeAccent.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
    
    // MARK: - Audio Delay Section
    
    private var audioDelaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.orange)
                }
                
                Text("Audio Delay")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(String(format: "%.2fs", viewModel.audioDelay))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.orange)
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.orange.opacity(0.15))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            // Slider Control
            HStack(spacing: 16) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.audioDelay -= 0.05
                    }
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.premiumCircleBackground)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.premiumCardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                
                Slider(value: $viewModel.audioDelay, in: -5.0...5.0, step: 0.05)
                    .accentColor(.orange)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.audioDelay += 0.05
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.premiumCircleBackground)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.premiumCardBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.premiumCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.premiumCardBorder, lineWidth: 1)
        )
    }
    
    // MARK: - Subtitles Section
    
    private var subtitlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "captions.bubble.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                }
                
                Text("Subtitles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: { showingFileImporter = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Import")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.15))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            
            // Subtitle List
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    // Off option
                    subtitleTrackRow(
                        title: "Off",
                        isSelected: !viewModel.subtitleManager.isEnabled,
                        isOff: true
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectSubtitleTrack(at: -1)
                        }
                    }
                    
                    // Available subtitles
                    ForEach(Array(viewModel.subtitleManager.availableTracks.enumerated()), id: \.offset) { index, subtitle in
                        subtitleTrackRow(
                            title: subtitle.name,
                            isSelected: viewModel.subtitleManager.isEnabled && viewModel.subtitleManager.selectedTrackIndex == index,
                            isOff: false
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectSubtitleTrack(at: index)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: isLandscape ? 300 : 400)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.premiumCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.premiumCardBorder, lineWidth: 1)
        )
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
    
    private func subtitleTrackRow(title: String, isSelected: Bool, isOff: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                    .lineLimit(1)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isOff ? .red : .homeAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.homeAccent.opacity(0.15) : Color.premiumCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.homeAccent.opacity(0.3) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
