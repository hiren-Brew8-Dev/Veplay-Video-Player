import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Binding var paddingBottom: CGFloat
    
    let tabs = ["Video", "Gallery", "Folder"]
    @AppStorage("isGridView") private var isGridView: Bool = true
    @State private var showSortSheet: Bool = false
    @State private var showSearch: Bool = false
    
    init(viewModel: DashboardViewModel, paddingBottom: Binding<CGFloat>) {
        self.viewModel = viewModel
        self._paddingBottom = paddingBottom
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Tab Bar
                if !viewModel.isSelectionMode {
                    topTabBar
                }
                
                // Content
                // Content using stable TabView
                TabView(selection: $viewModel.homeSelectedTab) {
                    VideoSectionView(viewModel: viewModel, paddingBottom: $paddingBottom)
                        .tag("Video")
                    
                    AlbumSectionView(viewModel: viewModel)
                        .tag("Gallery")
                    
                    FolderSectionView(viewModel: viewModel)
                        .tag("Folder")
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Block swipes in selection mode
                .allowsHitTesting(true) 
                .gesture(viewModel.isSelectionMode ? DragGesture() : nil)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .background(Color.homeBackground.edgesIgnoringSafeArea(.all))
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
    
    private var headerView: some View {
        HStack {
            HStack(spacing: AppDesign.Icons.internalSpacing) {
                Image(systemName: "play.circle.fill")
                    .appIconStyle(size: AppDesign.Icons.headerSize)
                Text("PLAYER")
                    .font(.system(size: AppDesign.Icons.headerSize, weight: .bold))
                    .foregroundColor(.homeTextPrimary)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: { /* Premium Action */  }) {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                        Text("Premium")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.homeTint)
                    .foregroundColor(.homeTextPrimary)
                    .cornerRadius(20)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }
    
    private var topTabBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 30) {
                    ForEach(tabs, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.homeSelectedTab = tab
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(tab)
                                    .font(.system(size: 16, weight: viewModel.homeSelectedTab == tab ? .bold : .semibold))
                                    .foregroundColor(viewModel.homeSelectedTab == tab ? .orange : .white.opacity(0.5))
                                
                                // Modern Indicator
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(viewModel.homeSelectedTab == tab ? Color.orange : Color.clear)
                                    .frame(width: 24, height: 3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22)
            }
            
            // Only show Search and Menu for Video tab
            if viewModel.homeSelectedTab == "Video" {
                HStack(spacing: 12) {
                    Button(action: { showSearch = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.premiumCircleBackground)
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .navigationDestination(isPresented: $showSearch) {
                        SearchView(viewModel: viewModel, contextTitle: "Videos", initialVideos: viewModel.importedVideos)
                    }
                    
                    Menu {
                        Button(action: { 
                            withAnimation { viewModel.isSelectionMode = true }
                        }) {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                        
                        Divider()
                        
                        Button(action: { isGridView = true }) {
                            Label("Grid", systemImage: "square.grid.2x2")
                        }
                        .accentColor(isGridView ? .orange : .white)
                        
                        Button(action: { isGridView = false }) {
                            Label("List", systemImage: "list.bullet")
                        }
                        .accentColor(!isGridView ? .orange : .white)
                        
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
