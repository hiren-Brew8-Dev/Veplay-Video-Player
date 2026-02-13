import SwiftUI

struct FolderSectionView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    @State private var showActionSheet = false
    @State private var activeFolder: Folder?
    @State private var showSearch = false
    
    @State private var showSortSheet = false
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showDeleteSelectedAlert = false
    
    var body: some View {
        ZStack {
            Color.homeBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                if viewModel.isSelectionMode {
                    selectionHeader
                } else if !viewModel.folders.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    utilityRow
                        .padding(.horizontal, AppDesign.Icons.horizontalPadding)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                }
                
                if viewModel.folders.isEmpty {
                    emptyStateView
                } else {
                    foldersScrollView
                }
            }
            
            if viewModel.isSelectionMode {
                selectionActionBar
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
        .alert("Delete Selected Folders", isPresented: $showDeleteSelectedAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                let foldersToDelete = viewModel.folders.filter { viewModel.selectedFolderIds.contains($0.id) }
                for folder in foldersToDelete {
                    viewModel.deleteFolder(folder)
                }
                viewModel.isSelectionMode = false
                viewModel.selectedFolderIds.removeAll()
            }
        } message: {
            Text("Are you sure you want to delete \(viewModel.selectedFolderIds.count) folders? This will remove all videos inside them.")
        }
        .sheet(isPresented: $showSortSheet) {
            CustomSortingView(sortOptionRaw: $viewModel.folderSortOptionRaw, title: "All Folders")
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .onChange(of: viewModel.isSelectionMode) { _, isSelectionMode in
            if !isSelectionMode {
                viewModel.selectedFolderIds.removeAll()
            }
        }
    }
    
    private var isAllSelected: Bool {
        return !viewModel.folders.isEmpty && viewModel.selectedFolderIds.count == viewModel.folders.count
    }
    
    private var selectionHeader: some View {
        HStack {
            Button(action: {
                if isAllSelected {
                    viewModel.selectedFolderIds.removeAll()
                } else {
                    viewModel.selectedFolderIds = Set(viewModel.folders.map { $0.id })
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(isAllSelected ? Color.orange : Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    
                    if isAllSelected {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 14, height: 14)
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(10)
            }
            
            Spacer()
            
            Text("Selected (\(viewModel.selectedFolderIds.count)/\(viewModel.folders.count))")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.white)
            
            Spacer()
            
            Button("Done") {
                viewModel.isSelectionMode = false
                viewModel.selectedFolderIds.removeAll()
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(.orange)
            .padding(.trailing, 10 + (isIpad ? 10 : 0))
        }
        .padding(.horizontal, AppDesign.Icons.horizontalPadding / 2)
        .padding(.vertical, isIpad ? 16 : 8)
        .background(Color.clear)
    }

    private var selectionActionBar: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack(spacing: 0) {
                Button(action: { showDeleteSelectedAlert = true }) {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(viewModel.selectedFolderIds.isEmpty ? Color.white.opacity(0.05) : Color.orange.opacity(0.1))
                                .frame(width: isIpad ? 60 : 44, height: isIpad ? 60 : 44)
                            
                            Image(systemName: "trash")
                                .font(.system(size: isIpad ? 28 : 20, weight: .semibold))
                                .foregroundColor(viewModel.selectedFolderIds.isEmpty ? .white.opacity(0.3) : .orange)
                        }
                        
                        Text("Delete")
                            .font(.system(size: isIpad ? 14 : 11, weight: .bold))
                            .foregroundColor(viewModel.selectedFolderIds.isEmpty ? .white.opacity(0.3) : .white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .disabled(viewModel.selectedFolderIds.isEmpty)
                .opacity(viewModel.selectedFolderIds.isEmpty ? 0.5 : 1.0)
            }
            .padding(.top, isIpad ? 20 : 12)
            .padding(.bottom, max(10, UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0))
            .background(
                LinearGradient(
                    colors: [.premiumGradientTop, .premiumGradientBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                VStack {
                    Rectangle()
                        .fill(Color.premiumCardBorder)
                        .frame(height: 1)
                    Spacer()
                }
            )
            .clipShape(RoundedCorner(radius: 32, corners: [.topLeft, .topRight]))
            .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: -5)
        }
        .ignoresSafeArea(.all, edges: .bottom)
        .transition(.move(edge: .bottom))
    }
    
    private var utilityRow: some View {
        HStack {
            // Sort Button
            Button(action: {
                withAnimation {
                    showSortSheet = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Sort by")
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                .foregroundColor(.white)
            }
            
            Spacer()
            
            HStack(spacing: isIpad ? 10 : 8) {
                // View Mode Toggle (Direct Icon)
                Button(action: {
                    withAnimation {
                        viewModel.isGridView.toggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: viewModel.isGridView ? "list.bullet" : "square.grid.2x2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                // Vertical Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 24)
                
                // Selection Mode
                Button(action: {
                    withAnimation {
                        viewModel.isSelectionMode = true
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        
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
                    .background(
                        LinearGradient(
                            colors: [Color.homeAccent, Color.homeAccent.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(25)
            }
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    private var foldersScrollView: some View {
        GeometryReader { geometry in
            let isLandscape = isIpad ? (geometry.size.width > geometry.size.height) : (geometry.size.width > 500)
            let currentWidth = geometry.size.width
            
            ScrollView {
                VStack(spacing: 20) {
                    Group {
                        if viewModel.isGridView {
                            foldersGrid(isLandscape: isLandscape, currentWidth: currentWidth)
                        } else {
                            foldersList(isLandscape: isLandscape)
                        }
                    }
                    .padding(.top, 10)
                }
                .padding(.bottom, viewModel.isSelectionMode ? 140 : 100)
            }
        }
    }
    
    private func foldersGrid(isLandscape: Bool, currentWidth: CGFloat) -> some View {
        LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: GridLayout.spacing(isLandscape: isLandscape)) {
            ForEach(viewModel.groupedFolders) { section in
                Section(header: sectionHeader(for: section.date)) {
                    ForEach(section.folders) { folder in
                        Button(action: {
                            handleFolderTap(folder)
                        }) {
                            FolderCardView(
                                folder: folder,
                                viewModel: viewModel,
                                onMenuAction: {
                                    viewModel.actionSheetTarget = .folder(folder)
                                    viewModel.actionSheetItems = folderActions(for: folder)
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        viewModel.showActionSheet = true
                                    }
                                },
                                size: GridLayout.itemSize(for: currentWidth, isLandscape: isLandscape),
                                isSelectionMode: viewModel.isSelectionMode,
                                isSelected: viewModel.selectedFolderIds.contains(folder.id)
                            )
                        }
                        .buttonStyle(.scalable)
                        .id(folder.id)
                        .simultaneousGesture(TapGesture().onEnded {
                            if !viewModel.isSelectionMode {
                                viewModel.markFolderAsAccessed(folder)
                            }
                        })
                    }
                }
            }
        }
        .padding(.horizontal, GridLayout.horizontalPadding)
    }
    
    private func foldersList(isLandscape: Bool) -> some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.groupedFolders) { section in
                Section(header: sectionHeader(for: section.date)) {
                    VStack(spacing: 0) {
                        ForEach(Array(section.folders.enumerated()), id: \.element.id) { index, folder in
                            Button(action: {
                                handleFolderTap(folder)
                            }) {
                                FolderRowView(
                                    folder: folder,
                                    viewModel: viewModel,
                                    onMenuAction: {
                                        viewModel.actionSheetTarget = .folder(folder)
                                        viewModel.actionSheetItems = folderActions(for: folder)
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                            viewModel.showActionSheet = true
                                        }
                                    },
                                    isSelectionMode: viewModel.isSelectionMode,
                                    isSelected: viewModel.selectedFolderIds.contains(folder.id)
                                )
                            }
                            .buttonStyle(.scalable)
                            .id(folder.id)
                            .simultaneousGesture(TapGesture().onEnded {
                                if !viewModel.isSelectionMode {
                                    viewModel.markFolderAsAccessed(folder)
                                }
                            })
                            
                            if index < section.folders.count - 1 {
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, viewModel.isSelectionMode ? 120 : 80)
                            }
                        }
                    }
                    .background(Color.premiumCardBackground)
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.premiumCardBorder, lineWidth: 1)
                    )
                    .padding(.horizontal, GridLayout.horizontalPadding)
                }
            }
        }
    }
    
    @ViewBuilder
    private func sectionHeader(for date: Date) -> some View {
        if date == .distantPast {
            EmptyView()
        } else {
            HStack {
                Text(sectionHeaderTitle(for: date).uppercased())
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, AppDesign.Icons.horizontalPadding)
        }
    }
    
    func sectionHeaderTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM"
            return formatter.string(from: date)
        }
    }

    private func handleFolderTap(_ folder: Folder) {
        if viewModel.isSelectionMode {
            if viewModel.selectedFolderIds.contains(folder.id) {
                viewModel.selectedFolderIds.remove(folder.id)
            } else {
                viewModel.selectedFolderIds.insert(folder.id)
            }
        } else {
            viewModel.navigationPath.append(DashboardViewModel.NavigationDestination.folderDetail(folder))
        }
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
