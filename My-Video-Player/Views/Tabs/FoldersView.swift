import SwiftUI

struct FoldersView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @AppStorage("isGridView") private var isGridView: Bool = true
    @State private var showCreateFolder = false
    @State private var folderToRename: Folder?
    @State private var showRenameAlert = false
    @State private var newFolderName = ""
    @State private var animatedIndices: Set<UUID> = []
    
    @State private var showActionSheet = false
    @State private var activeFolder: Folder?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Header with Back Button
                HStack {
                    StandardIconButton(icon: "chevron.left", action: {
                        presentationMode.wrappedValue.dismiss()
                    })
                    
                    Spacer()
                    
                    Text("Folders")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.homeTextPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isGridView.toggle()
                        }
                    }) {
                        Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                            .font(.system(size: 20))
                            .foregroundColor(.homeAccent)
                    }
                }
                .padding()
                
                GeometryReader { geometry in
                    let isLandscape = geometry.size.width > geometry.size.height
                    let currentWidth = geometry.size.width
                    
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack {
                            if isGridView {
                                LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: 16) {
                                    ForEach(Array(viewModel.folders.enumerated()), id: \.element.id) { index, folder in
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
                                                        viewModel.deleteFolder(folder)
                                                    })
                                                ]
                                                viewModel.showActionSheet = true
                                            }, size: GridLayout.itemSize(for: currentWidth, isLandscape: isLandscape))
                                                .opacity(animatedIndices.contains(folder.id) ? 1 : 0)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(viewModel.folders) { folder in
                                        NavigationLink(destination: FolderDetailView(initialFolder: folder, viewModel: viewModel)) {
                                            HStack(spacing: 16) {
                                                Image(systemName: "folder.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.homeAccent)
                                                    .frame(width: 44, height: 44)
                                                    .background(Color.homeCardBackground)
                                                    .cornerRadius(8)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(folder.name)
                                                        .font(.system(size: 16, weight: .semibold))
                                                        .foregroundColor(.homeTextPrimary)
                                                    Text("\(folder.videos.count) Videos")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.homeTextSecondary)
                                                }
                                                
                                                Spacer()
                                                
                                                Button(action: {
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
                                                }) {
                                                    Image(systemName: "ellipsis")
                                                        .foregroundColor(.homeTextSecondary)
                                                        .padding(8)
                                                }
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 8)
                                            .background(Color.homeCardBackground.opacity(0.3))
                                            .cornerRadius(12)
                                        }
                                        .padding(.horizontal, isLandscape ? (isIpad ? 80 : 40) : 0)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 80)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showCreateFolder) {
            CreateFolderSheet(viewModel: viewModel)
        }
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
