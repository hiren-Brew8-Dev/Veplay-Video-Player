import SwiftUI
import Photos

struct HistorySection: View {
    let historyItems: [HistoryItem]
    let viewModel: DashboardViewModel?
    
    var body: some View {
        if !historyItems.isEmpty {
            VStack(alignment: .leading) {
                HStack {
                    Text("History")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button("View All") { }
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(historyItems, id: \.self) { item in
                            // Convert HistoryItem to VideoItem for display re-use
                            let video = VideoItem(
                                id: item.id ?? UUID(),
                                asset: fetchAsset(for: item.videoUrlString),
                                title: item.title ?? "Unknown",
                                duration: item.duration,
                                creationDate: item.timestamp ?? Date(),
                                fileSizeBytes: item.fileSizeBytes
                            )
                            
                            Button(action: {
                                viewModel?.playingVideo = video
                            }) {
                                VideoCardView(video: video, viewModel: viewModel)
                                    .frame(width: 120) // Fixed width for horizontal scroll items
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            }
        }
    }
    
    func formatDuration(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? "00:00"
    }

    private func fetchAsset(for identifier: String?) -> PHAsset? {
        guard let identifier = identifier else { return nil }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return fetchResult.firstObject
    }
}
