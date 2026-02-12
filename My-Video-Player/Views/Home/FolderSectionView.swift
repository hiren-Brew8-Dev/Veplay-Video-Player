import SwiftUI

struct FolderSectionView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    @State private var showActionSheet = false
    @State private var activeFolder: Folder?
    @State private var showSearch = false
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.premiumGradientTop, .premiumGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                headerView
                
                ZStack(alignment: .bottomTrailing) {
                    if viewModel.folders.isEmpty {
                        VStack(spacing: 0) {
                            Spacer()
                                .frame(height: 80)
                            
                            VStack(spacing: 24) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.05))
                                        .frame(width: 100, height: 100)
                                    
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.2))
                                        .offset(x: 2) // Optical balance
                                }
                                
                                VStack(spacing: 8) {
                                    Text("No Folders Yet")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("Create folders to organize your videos\nand keep your library tidy.")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.5))
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(4)
                                }
                                .padding(.horizontal, 40)
                                
                                Button(action: {
                                    viewModel.showCreateFolderAlert = true
                                }) {
                                    Text("Create Folder")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 40)
                                        .padding(.vertical, 16)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.homeAccent, Color.homeAccent.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .cornerRadius(30)
                                        .shadow(color: Color.homeAccent.opacity(0.4), radius: 15, x: 0, y: 8)
                                }
                                .buttonStyle(.scalable)
                                .padding(.top, 8)
                            }
                            
                            Spacer()
                        }
                    } else {
                        GeometryReader { geometry in
                            let isLandscape = geometry.size.width > geometry.size.height
                            let currentWidth = geometry.size.width
                            
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: GridLayout.spacing(isLandscape: isLandscape)) {
                                        ForEach(viewModel.sortedFolders) { folder in
                                            Button(action: {
                                                viewModel.navigationPath.append(DashboardViewModel.NavigationDestination.folderDetail(folder))
                                            }) {
                                                FolderCardView(folder: folder, viewModel: viewModel, onMenuAction: {
                                                    viewModel.actionSheetTarget = .folder(folder)
                                                    viewModel.actionSheetItems = [
                                                        CustomActionItem(title: "Rename", icon: "pencil", role: nil, action: {
                                                            viewModel.folderToRename = folder
                                                            viewModel.renameFolderName = folder.name
                                                            viewModel.showRenameFolderAlert = true
                                                        }),
                                                        CustomActionItem(title: "Delete", icon: "trash", role: .destructive, action: {
                                                            viewModel.folderToDelete = folder
                                                            viewModel.showDeleteFolderAlert = true
                                                        })
                                                    ]
                                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                                        viewModel.showActionSheet = true
                                                    }
                                                }, size: GridLayout.itemSize(for: currentWidth, isLandscape: isLandscape))
                                            }
                                            .buttonStyle(.scalable)
                                            .id(folder.id) // Important for scrolling
                                            .simultaneousGesture(TapGesture().onEnded {
                                                viewModel.markFolderAsAccessed(folder)
                                            })
                                        }
                                    }
                                    .padding(.horizontal, GridLayout.horizontalPadding)
                                    .padding(.bottom, 90)
                                }
                                .onChange(of: viewModel.highlightFolderId) { oldId, newId in
                                    if let id = newId {
                                        withAnimation {
                                            proxy.scrollTo(id, anchor: .center)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                .background(Color.clear)
                .alert("Rename Folder", isPresented: $viewModel.showRenameFolderAlert) {
                    TextField("New Name", text: $viewModel.renameFolderName)
                    Button("Cancel", role: .cancel) {
                        viewModel.folderToRename = nil
                    }
                    Button("Rename") {
                        if let folder = viewModel.folderToRename {
                            viewModel.renameFolder(folder, to: viewModel.renameFolderName)
                        }
                        viewModel.folderToRename = nil
                    }
                } message: {
                    Text("Enter a new name for this folder")
                }
                .alert("Delete Folder", isPresented: $viewModel.showDeleteFolderAlert) {
                    Button("Cancel", role: .cancel) {
                        viewModel.folderToDelete = nil
                    }
                    Button("Delete", role: .destructive) {
                        if let folder = viewModel.folderToDelete {
                            viewModel.deleteFolder(folder)
                        }
                        viewModel.folderToDelete = nil
                    }
                } message: {
                    if let folder = viewModel.folderToDelete {
                        Text("Are you sure you want to delete '\(folder.name)'? All videos inside will be removed.")
                    } else {
                        Text("Are you sure you want to delete this folder?")
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                if !viewModel.navigationPath.isEmpty {
                    viewModel.navigationPath.removeLast()
                }
            }) {
                ZStack {
                    Circle()
                        .fill(Color.premiumCircleBackground)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text("All Folders")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: {
                viewModel.showCreateFolderAlert = true
            }) {
                ZStack {
                    Circle()
                        .fill(Color.premiumCircleBackground)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
        .background(Color.clear)
    }
}
