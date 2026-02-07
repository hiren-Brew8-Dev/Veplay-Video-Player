import SwiftUI

struct TrackSelectionView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool
    let isLandscape: Bool
    
    var body: some View {
        AudioTrackSettingsView(
            viewModel: viewModel,
            isPresented: $isPresented,
            isLandscape: isLandscape,
            onBack: { isPresented = false }
        )
    }
}

struct AudioTrackSettingsView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @Binding var isPresented: Bool
    let isLandscape: Bool
    var onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle (Only visible in portrait)
            if !isLandscape {
                Capsule()
                    .fill(Color.homeTextSecondary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
            }
            
            // Header
            HStack {
                StandardIconButton(icon: "chevron.left", action: onBack)
                
                Spacer()
                
                Text("Audio Track")
                    .font(.headline)
                    .foregroundColor(.homeTextPrimary)
                
                Spacer()
                
                // Invisible spacer to balance the back button
                StandardIconButton(icon: "chevron.left", color: .clear, bg: .clear, action: {})
            }
            .padding(.horizontal)
            // Removed padding(.bottom, 10) here
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Tracks List inside ScrollView
            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.availableAudioTracks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "speaker.slash.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.homeTextSecondary)
                                .padding(.top, 40)
                            
                            Text("No Audio Tracks Available")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.homeTextSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        // Disable option (Mute)
                        trackRow(
                            title: "Disable",
                            isSelected: viewModel.selectedAudioTrackIndex == -1,
                            action: { viewModel.selectAudioTrack(at: -1) }
                        )
                        
                        Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                        
                        // Tracks
                        ForEach(Array(viewModel.availableAudioTracks.enumerated()), id: \.offset) { index, trackName in
                            trackRow(
                                title: trackName,
                                isSelected: viewModel.selectedAudioTrackIndex == index,
                                action: { viewModel.selectAudioTrack(at: index) }
                            )
                            
                            if index < viewModel.availableAudioTracks.count - 1 {
                                Divider().background(Color.sheetDivider).padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: isLandscape ? .infinity : 250) // Allow full height in landscape
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Audio Delay Section (Sticky Footer)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Audio delay")
                        .font(.system(size: 15))
                        .foregroundColor(.homeTextPrimary)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f ms", viewModel.audioDelay * 1000))
                        .font(.system(size: 15))
                        .foregroundColor(.homeTextPrimary)
                    
                    Button(action: {
                        viewModel.audioDelay = 0.0
                    }) {
                        Text("Reset")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.homeBackground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.homeTextPrimary)
                            .cornerRadius(4)
                    }
                    .padding(.leading, 8)
                }
                
                Slider(value: $viewModel.audioDelay, in: -5.0...5.0, step: 0.1)
                    .accentColor(.homeAccent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, isLandscape ? 20 : 40)
            .background(Color.sheetBackground)
            .opacity(viewModel.selectedAudioTrackIndex == -1 ? 0.5 : 1.0)
            .allowsHitTesting(viewModel.selectedAudioTrackIndex != -1)
        }
        .padding(.trailing, isLandscape ? 30 : 0)
        .background(Color.sheetBackground)
        .if(isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .bottomLeft])
        }
        .if(!isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .topRight])
        }
    }
    
    func trackRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.homeTextPrimary)
                    .padding(.leading, 16)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.homeAccent : Color.homeTextSecondary.opacity(0.5), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.homeAccent)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.trailing, 16)
            }
            .frame(height: 54)
            .contentShape(Rectangle())
        }
    }
}
