import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Binding var paddingBottom: CGFloat
    
    @State private var selectedTab: String = "Video"
    let tabs = ["Video", "Album", "Folder"]
    @AppStorage("isGridView") private var isGridView: Bool = true
    @State private var showSortSheet: Bool = false
    @State private var showSearch: Bool = false
    
    init(viewModel: DashboardViewModel, paddingBottom: Binding<CGFloat>) {
        self.viewModel = viewModel
        self._paddingBottom = paddingBottom
        
        // Custom Segmented Control Appearance if needed, 
        // but we will implement a custom tab bar as per design.
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Top Tab Bar
                if !viewModel.isSelectionMode {
                    topTabBar
                }
                
                // Content
                ZStack {
                    if selectedTab == "Video" {
                        VideoSectionView(viewModel: viewModel, paddingBottom: $paddingBottom)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                    } else if selectedTab == "Album" {
                        AlbumSectionView(viewModel: viewModel)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                    } else if selectedTab == "Folder" {
                        FolderSectionView(viewModel: viewModel)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                    }
                }
                .id(selectedTab)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedTab)
            }
        }
        .background(Color.themeBackground.edgesIgnoringSafeArea(.all))
        .navigationBarHidden(true)
    }
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                Text("PLAYER")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
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
                    .background(Color.blue)
                    .foregroundColor(.white)
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
                HStack(spacing: 25) {
                    ForEach(tabs, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }) {
                            VStack(spacing: 6) {
                                Text(tab)
                                    .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                                    .foregroundColor(selectedTab == tab ? .orange : .gray)
                                
                                ZStack {
                                    if selectedTab == tab {
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(Color.orange)
                                            .frame(height: 3)
                                            .matchedGeometryEffect(id: "TabIndicator", in: namespace)
                                    } else {
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(Color.clear)
                                            .frame(height: 3)
                                    }
                                }
                                .frame(width: 40)
                            }
                        }
                        .buttonStyle(.scalable)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            if selectedTab == "Video" {
                HStack(spacing: 16) {
                    Button(action: { showSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .navigationDestination(isPresented: $showSearch) {
                        SearchView(viewModel: viewModel, contextTitle: "Videos")
                    }
                    
                    Menu {
                        Button(action: { showSortSheet = true }) {
                            Label("Sort by", systemImage: "arrow.up.arrow.down")
                        }
                        
                        Button(action: { isGridView.toggle() }) {
                            Label(isGridView ? "List View" : "Grid View", systemImage: isGridView ? "list.bullet" : "square.grid.2x2")
                        }
                        
                        Button(action: { viewModel.isSelectionMode = true }) {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.trailing, 16)
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showSortSheet) {
            CustomSortingView(sortOptionRaw: $viewModel.videoSortOptionRaw, title: "Videos")
        }
        .frame(height: 44)
        .padding(.vertical, 8)
    }
    
    @Namespace private var namespace
}
