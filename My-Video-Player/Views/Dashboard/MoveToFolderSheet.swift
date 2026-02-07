import SwiftUI

struct MoveToFolderSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: DashboardViewModel
    let video: VideoItem
    
    var body: some View {
        NavigationView {
            List {
                // Only show user folders and Downloads
                ForEach(viewModel.folders.filter { $0.url != nil || $0.name == "Downloads" }) { folder in
                    Button(action: {
                        viewModel.moveVideo(video, to: folder)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .appIconStyle(size: AppDesign.Icons.rowIconSize, color: .homeTint)
                            Text(folder.name)
                                .foregroundColor(.primary)
                            Spacer()
                            if folder.name == "Downloads" {
                                Text("(Default)")
                                    .font(.caption)
                                    .foregroundColor(.homeTextSecondary)
                            }
                        }
                    }
                }
            }
            .navigationBarTitle("Move to Folder", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}
