import SwiftUI

struct FolderSectionView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    @State private var showActionSheet = false
    @State private var activeFolder: Folder?
    @State private var showSearch = false
    
    @State private var showSortSheet = false
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
                headerView
                
                if viewModel.folders.isEmpty {
                    emptyStateView
                } else {
                    foldersScrollView
                }
            }
        }
        .alert("Rename Folder", isPresented: $viewModel.showRenameFolderAlert) {
            TextField("Folder Name", text: $viewModel.renameFolderName)
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
        .sheet(isPresented: $showSortSheet) {
            CustomSortingView(sortOptionRaw: $viewModel.folderSortOptionRaw, title: "All Folders")
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
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
            
            HStack(spacing: 12) {
                if !viewModel.folders.isEmpty {
                    Menu {
                        Picker(selection: $viewModel.isGridView, label: EmptyView()) {
                            Label("Grid View", systemImage: "square.grid.2x2").tag(true)
                            Label("List View", systemImage: "list.bullet").tag(false)
                        }
                        .pickerStyle(.inline)
                        
                        Divider()
                        
                        Button(action: { showSortSheet = true }) {
                            Label("Sort by", systemImage: "arrow.up.arrow.down")
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.premiumCircleBackground)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "ellipsis")
                                .rotationEffect(.degrees(90))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
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
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
        .background(Color.clear)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 50))
                    .foregroundColor(.white.opacity(0.2))
            }
            
            VStack(spacing: 8) {
                Text("No folders yet")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Create a folder to organize your videos")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Button(action: {
                viewModel.showCreateFolderAlert = true
            }) {
                Text("Create Folder")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(25)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var foldersScrollView: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let currentWidth = geometry.size.width
            
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        if viewModel.isGridView {
                            foldersGrid(isLandscape: isLandscape, currentWidth: currentWidth)
                        } else {
                            foldersList()
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(.bottom, 100)
            }
        }
    }
    
    private func foldersGrid(isLandscape: Bool, currentWidth: CGFloat) -> some View {
        LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: GridLayout.spacing(isLandscape: isLandscape)) {
            ForEach(viewModel.sortedFolders) { folder in
                Button(action: {
                    viewModel.navigationPath.append(DashboardViewModel.NavigationDestination.folderDetail(folder))
                }) {
                    FolderCardView(folder: folder, viewModel: viewModel, onMenuAction: {
                        viewModel.actionSheetTarget = .folder(folder)
                        viewModel.actionSheetItems = folderActions(for: folder)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.showActionSheet = true
                        }
                    }, size: GridLayout.itemSize(for: currentWidth, isLandscape: isLandscape))
                }
                .buttonStyle(.scalable)
                .id(folder.id)
                .simultaneousGesture(TapGesture().onEnded {
                    viewModel.markFolderAsAccessed(folder)
                })
            }
        }
        .padding(.horizontal, GridLayout.horizontalPadding)
    }
    
    private func foldersList() -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.sortedFolders.enumerated()), id: \.element.id) { index, folder in
                Button(action: {
                    viewModel.navigationPath.append(DashboardViewModel.NavigationDestination.folderDetail(folder))
                }) {
                    FolderRowView(folder: folder, viewModel: viewModel, onMenuAction: {
                        viewModel.actionSheetTarget = .folder(folder)
                        viewModel.actionSheetItems = folderActions(for: folder)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.showActionSheet = true
                        }
                    })
                }
                .buttonStyle(.scalable)
                .id(folder.id)
                .simultaneousGesture(TapGesture().onEnded {
                    viewModel.markFolderAsAccessed(folder)
                })
                
                if index < viewModel.folders.count - 1 {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.leading, 80)
                }
            }
        }
        .background(Color.premiumCardBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.premiumCardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 10)
    }

    private func folderActions(for folder: Folder) -> [CustomActionItem] {
        [
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
    }
}
