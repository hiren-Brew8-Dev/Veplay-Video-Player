import SwiftUI

struct FoldersView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Environment(\.presentationMode) var presentationMode
    
    private let columns = GridLayout.gridColumns
    
    @AppStorage("isGridView") private var isGridView: Bool = true
    @State private var showCreateFolder = false
    @State private var folderToRename: Folder?
    @State private var showRenameAlert = false
    @State private var newFolderName = ""
    @State private var animatedIndices: Set<UUID> = []
    
    @State private var showActionSheet = false
    @State private var activeFolder: Folder?
    
    var body: some View {
        // NavigationView removed to support Global Navigation
        ZStack(alignment: .bottomTrailing) {
            Color.themeBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Header with Back Button
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding(10)
                            .background(Color.themeSurface)
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Folders")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            isGridView.toggle()
                        }
                    }) {
                        Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                
                ScrollView(.vertical, showsIndicators: true) {
                    VStack {
                        if isGridView {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(Array(viewModel.folders.enumerated()), id: \.element.id) { index, folder in
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
                                                .foregroundColor(.orange)
                                                .frame(width: 44, height: 44)
                                                .background(Color.themeSurface)
                                                .cornerRadius(8)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(folder.name)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.white)
                                                Text("\(folder.videos.count) Videos")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
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
                                                    .foregroundColor(.gray)
                                                    .padding(8)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(Color.themeSurface.opacity(0.3))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
            /* FAB Removed as requested */
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onAppear {
             // Ensure Tab Bar is hidden via toolbar modifier, not global appearance
             // UITabBar.appearance().isHidden = false // Do not toggle global state here
        }
             // Note: The parent `DashboardView` has the TabView.
        
        .toolbar(.hidden, for: .tabBar) // SwiftUI 4+
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
    
    // .navigationViewStyle(.stack) removed
}

