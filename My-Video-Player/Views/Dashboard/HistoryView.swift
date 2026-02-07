import SwiftUI
import Photos

struct HistoryView: View {
    let historyItems: [HistoryItem]
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var isGridView: Bool = true
    // @State private var selectedVideo: VideoItem?
    
    var body: some View {
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .appIconStyle(size: AppDesign.Icons.toolbarSize, weight: .bold, color: .homeTextPrimary)
                            .padding(10)
                            .background(Color.homeCardBackground)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("History")
                        .font(.system(size: AppDesign.Icons.headerSize, weight: .bold))
                        .foregroundColor(.homeTextPrimary)
                    
                    Spacer()
                    
                    HStack(spacing: 15) {
                        Menu {
                            Button(action: { isGridView = true }) {
                                Label("Grid", systemImage: "square.grid.2x2")
                            }
                            Button(action: { isGridView = false }) {
                                Label("List", systemImage: "list.bullet")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .appIconStyle()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.homeBackground)
                
                ScrollView {
                    if isGridView {
                        LazyVGrid(columns: GridLayout.gridColumns, spacing: GridLayout.spacing) {
                            ForEach(historyItems, id: \.self) { item in
                                let video = videoFromHistory(item)
                                Button(action: {
                                    viewModel.currentPlaylist = historyItems.map { videoFromHistory($0) }
                                    viewModel.playingVideo = video
                                }) {
                                    VideoCardView(video: video, viewModel: viewModel)
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 80)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(historyItems, id: \.self) { item in
                                let video = videoFromHistory(item)
                                Button(action: {
                                    viewModel.currentPlaylist = historyItems.map { videoFromHistory($0) }
                                    viewModel.playingVideo = video
                                }) {
                                    VideoRowView(video: video, viewModel: viewModel)
                                }
                                Divider().background(Color.sheetDivider)
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        // .fullScreenCover(item: $selectedVideo) { video in
        //     PlayerView(video: video)
        // }
    }
    
    private func videoFromHistory(_ item: HistoryItem) -> VideoItem {
        let isLocal = item.isLocalFile
        let url = isLocal ? URL(fileURLWithPath: item.videoUrlString ?? "") : nil
        let asset = !isLocal ? fetchAsset(for: item.videoUrlString) : nil
        
        return VideoItem(
            id: item.id ?? UUID(),
            asset: asset,
            title: item.title ?? "Unknown",
            duration: item.duration,
            creationDate: item.timestamp ?? Date(),
            fileSizeBytes: item.fileSizeBytes,
            url: url
        )
    }

    private func fetchAsset(for identifier: String?) -> PHAsset? {
        guard let identifier = identifier else { return nil }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.firstObject
    }
}
