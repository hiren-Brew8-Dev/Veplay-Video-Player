import SwiftUI
import UniformTypeIdentifiers

struct SubtitleSettingsView: View {
    @ObservedObject var subtitleManager: SubtitleManager
    @Binding var isPresented: Bool
    let isLandscape: Bool
    var onBack: (() -> Void)? = nil
    
    @State private var showEditSheet = false
    @State private var showOnlineSheet = false
    @State private var showingFileImporter = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            // Drag Handle
            if !isLandscape {
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    if let onBack = onBack {
                        Button(action: onBack) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                        }
                    } else {
                         // Invisible spacer to balance if no back button (portrait usually has back)
                         Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.clear)
                            .padding(10)
                    }
                    
                    Spacer()
                    
                    Text("Subtitle Track")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer to balance
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                        .padding(10)
                }
                .padding(.horizontal)
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Actions
                actionGridView
                    .padding(.vertical, 14) // Spacing around grid
                
                Divider()
                    .background(Color.gray.opacity(0.3))
                
                // Tracks
                ScrollView {
                    VStack(spacing: 0) {
                        trackRow(title: "Disable", isSelected: subtitleManager.selectedTrackIndex == -1) {
                            subtitleManager.selectTrack(at: -1)
                        }
                        
                        if !subtitleManager.availableTracks.isEmpty {
                            Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                        }
                        
                        ForEach(Array(subtitleManager.availableTracks.enumerated()), id: \.element.id) { index, track in
                            trackRow(title: track.displayName, isSelected: subtitleManager.selectedTrackIndex == index) {
                                subtitleManager.selectTrack(at: index)
                            }
                            if index < subtitleManager.availableTracks.count - 1 {
                                Divider().background(Color.gray.opacity(0.2)).padding(.leading, 16)
                            }
                        }
                    }
                }
                .frame(maxHeight: isLandscape ? .infinity : 250) // Consistent max height
            }
        }
        .padding(.trailing, isLandscape ? 30 : 0)
        .background(Color(UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)))
        .if(isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .bottomLeft])
        }
        .if(!isLandscape) { view in
            view.cornerRadiusLocal(20, corners: [.topLeft, .topRight])
        }
        .shadow(color: Color.black.opacity(0.5), radius: 10, x: isLandscape ? -5 : 0, y: isLandscape ? 0 : -5)
        .sheet(isPresented: $showEditSheet) {
            SubtitleEditView(isPresented: $showEditSheet, subtitleManager: subtitleManager)
                .presentationDetents([.fraction(0.5)])
        }
        .sheet(isPresented: $showOnlineSheet) {
            SubtitleOnlineView(isPresented: $showOnlineSheet, subtitleManager: subtitleManager)
                .presentationDetents([.large])
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [UTType.plainText, UTType(filenameExtension: "srt")!, UTType.text],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                if url.startAccessingSecurityScopedResource() {
                    subtitleManager.loadSubtitle(from: url)
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }
    }
    
    var actionGridView: some View {
        HStack(spacing: 40) {
            actionButton(title: "Smart Edit", icon: "square.and.pencil") {
                showEditSheet = true
            }
            
            actionButton(title: "Quick Import", icon: "doc.badge.arrow.up") {
                showingFileImporter = true
            }
            
            actionButton(title: "Go Online", icon: "globe") {
                showOnlineSheet = true
            }
        }
    }
    
    func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.system(size: 11)) 
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: true, vertical: false)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    func trackRow(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.leading, 16)
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.orange : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.trailing, 16)
            }
            .frame(height: 54) // Matched to Audio Sheet (was 50)
            .contentShape(Rectangle())
        }
    }
}

extension SubtitleTrack {
    var displayName: String {
        if name.isEmpty { return "Unknown Track" }
        return name
    }
}
