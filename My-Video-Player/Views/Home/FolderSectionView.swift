import SwiftUI

struct FolderSectionView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    
    private let columns = GridLayout.gridColumns
    
    @State private var showActionSheet = false
    @State private var activeFolder: Folder?
    @State private var folderToRename: Folder?
    @State private var showRenameAlert = false
    @State private var showDeleteAlert = false
    @State private var newFolderName = ""
    @State private var folderToDelete: Folder?
    @State private var showSearch = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Folder sub-header
            
            ZStack(alignment: .bottomTrailing) {
                ZStack(alignment: .bottomTrailing) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: GridLayout.spacing) {
                                ForEach(viewModel.folders) { folder in
                                    NavigationLink(destination: FolderDetailView(initialFolder: folder, viewModel: viewModel)) {
                                        FolderCardView(folder: folder, viewModel: viewModel, onMenuAction: {
                                            viewModel.actionSheetTarget = .folder(folder)
                                            viewModel.actionSheetItems = [
                                                CustomActionItem(title: "Rename", icon: "pencil", role: nil, action: {
                                                    folderToRename = folder
                                                    newFolderName = folder.name
                                                    showRenameAlert = true
                                                }),
                                                CustomActionItem(title: "Delete", icon: "trash", role: .destructive, action: {
                                                    folderToDelete = folder
                                                    showDeleteAlert = true
                                                })
                                            ]
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                viewModel.showActionSheet = true
                                            }
                                        })
                                    }
                                    .buttonStyle(.scalable)
                                    .id(folder.id) // Important for scrolling
                                }
                            }
                            .padding(.horizontal, GridLayout.horizontalPadding)
                            .padding(.bottom, 90)
                            
                            if viewModel.folders.isEmpty {
                                VStack(spacing: 12) {
                                    Text("No folders yet")
                                        .font(.headline)
                                        .foregroundColor(.homeTextSecondary)
                                    Text("Create folders to organize your videos")
                                        .font(.caption)
                                        .foregroundColor(.homeTextSecondary)
                                }
                                .padding(.top, 40)
                            }
                        }
                        .onChange(of: viewModel.highlightFolderId) { oldId, newId in
                            if let id = newId {
                                withAnimation {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                    // Removed external .padding(.bottom, 80)
                }
            }
            
            .background(Color.homeBackground)
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
            .alert("Delete Folder", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { folderToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let folder = folderToDelete {
                        viewModel.deleteFolder(folder)
                    }
                    folderToDelete = nil
                }
            } message: {
                if let folder = folderToDelete {
                    Text("Are you sure you want to delete '\(folder.name)'? All videos inside will be removed.")
                } else {
                    Text("Are you sure you want to delete this folder?")
                }
            }
        }
        
    }
}
