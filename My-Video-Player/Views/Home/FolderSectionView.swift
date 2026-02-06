import SwiftUI

struct FolderSectionView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    
    private let columns = GridLayout.gridColumns
    
    @State private var showActionSheet = false
    @State private var activeFolder: Folder?
    @State private var folderToRename: Folder?
    @State private var showRenameAlert = false
    @State private var newFolderName = ""
    @State private var showSearch = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Folder sub-header
            HStack {
                Text("Folders")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(viewModel.folders) { folder in
                            NavigationLink(destination: FolderDetailView(initialFolder: folder, viewModel: viewModel)) {
                                FolderCardView(folder: folder, onMenuAction: {
                                    viewModel.actionSheetTarget = .folder(folder)
                                    viewModel.actionSheetItems = [
                                        CustomActionItem(title: "Rename", icon: "pencil", role: nil, action: {
                                            folderToRename = folder
                                            newFolderName = folder.name
                                            showRenameAlert = true
                                        }),
                                        CustomActionItem(title: "Delete", icon: "trash", role: .destructive, action: {
                                            viewModel.deleteFolder(folder)
                                        })
                                    ]
                                    viewModel.showActionSheet = true
                                })
                            }
                            .buttonStyle(.scalable)
                        }
                    }
                    .padding(.horizontal, 10)
                    
                    if viewModel.folders.isEmpty {
                        VStack(spacing: 12) {
                            Text("No folders yet")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Create folders to organize your videos")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 40)
                    }
                }
                // Removed external .padding(.bottom, 80)
            }
        }
        
        .background(Color.themeBackground)
        .alert("Rename Folder", isPresented: $showRenameAlert) {
            TextField("New Name", text: $newFolderName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let folder = folderToRename {
                    viewModel.renameFolder(folder, to: newFolderName)
                }
            }
        } message: {
            Text("Enter a new name for this folder")
        }
    }
}
