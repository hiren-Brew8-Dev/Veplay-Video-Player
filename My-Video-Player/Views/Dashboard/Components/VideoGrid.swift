import SwiftUI

struct VideoGrid: View {
    let videos: [VideoItem]
    let viewModel: DashboardViewModel?
    let onTap: (VideoItem) -> Void
    let onMenuAction: (VideoItem, VideoGridAction) -> Void
    
    enum VideoGridAction {
        case play
        case favorite
        case move
        case rename
        case delete
        case share
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 100), spacing: 10)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(videos) { video in
                Button(action: {
                    onTap(video)
                }) {
                    VideoCardView(video: video, viewModel: viewModel)
                        .contextMenu {
                            Button {
                                onMenuAction(video, .play)
                            } label: {
                                Label("Play", systemImage: "play.fill")
                            }
                            
                            Button {
                                onMenuAction(video, .favorite)
                            } label: {
                                Label("Favorite", systemImage: "heart")
                            }
                            
                            Button {
                                onMenuAction(video, .move)
                            } label: {
                                Label("Move to Folder", systemImage: "folder")
                            }
                            
                            Button {
                                onMenuAction(video, .rename)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive) {
                                onMenuAction(video, .delete)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
