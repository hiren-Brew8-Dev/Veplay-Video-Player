import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Binding var paddingBottom: CGFloat
    
    let tabs = ["Video", "Gallery"]
    @AppStorage("isGridView") private var isGridView: Bool = true
    @State private var showSortSheet: Bool = false
    @State private var showSearch: Bool = false
    
    init(viewModel: DashboardViewModel, paddingBottom: Binding<CGFloat>) {
        self.viewModel = viewModel
        self._paddingBottom = paddingBottom
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Header
            if !viewModel.isSelectionMode {
                topTabBar
                    .background(Color.homeBackground)
            }
            
            // Content using stable TabView
            TabView(selection: $viewModel.homeSelectedTab) {
                VideoSectionView(viewModel: viewModel, paddingBottom: $paddingBottom)
                    .tag("Video")
                
                AlbumSectionView(viewModel: viewModel)
                    .tag("Gallery")
                
            }
           
            .tabViewStyle(.page(indexDisplayMode: .never))
            .gesture(viewModel.isSelectionMode ? DragGesture() : nil)
        }
        
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.homeBackground)
        .navigationBarHidden(true)
        .onAppear {
            // Ensure tab bar is visible when home view appears
            viewModel.isTabBarHidden = false
        }
        .onChange(of: viewModel.homeSelectedTab) { oldTab, newTab in
            // Ensure tab bar is visible when switching between Video/Gallery/Folder
            viewModel.isTabBarHidden = false
        }
    }
    
    private var topTabBar: some View {
        HStack(spacing: 0) {
            // Logo & Title Leading
            HStack(spacing: AppDesign.Icons.internalSpacing) {
                Image(systemName: "play.circle.fill")
                    .appIconStyle(size: AppDesign.Icons.headerSize)
                Text("PLAYER")
                    .font(.system(size: AppDesign.Icons.headerSize, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
            }
            .padding(.leading, 16)
            
            Spacer()
            
            // Show Search and Menu for Video tab
            if viewModel.homeSelectedTab == "Video" && !viewModel.importedVideos.isEmpty  {
                HStack(spacing: 12) {
                    
                    Menu {
                        Button(action: { 
                            withAnimation { viewModel.isSelectionMode = true }
                        }) {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                        
                        Divider()
                        
                        Picker(selection: $isGridView, label: EmptyView()) {
                            Label("Grid", systemImage: "square.grid.2x2").tag(true)
                            Label("List", systemImage: "list.bullet").tag(false)
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
                .padding(.trailing, 16)
            }
        }
        
        .sheet(isPresented: $showSortSheet) {
            CustomSortingView(sortOptionRaw: (viewModel.homeSelectedTab == "Video" ? $viewModel.videoSortOptionRaw : (viewModel.homeSelectedTab == "Gallery" ? $viewModel.gallerySortOptionRaw : $viewModel.folderSortOptionRaw)), title: viewModel.homeSelectedTab == "Gallery" ? "Gallery" : viewModel.homeSelectedTab)
        }
        .frame(height: 44)
        .padding(.vertical, 8)
    }
    
    @Namespace private var namespace
}
