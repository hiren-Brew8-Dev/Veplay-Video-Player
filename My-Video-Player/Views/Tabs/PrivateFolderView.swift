import SwiftUI

struct PrivateFolderView: View {
    @StateObject private var authService = BiometricAuthService.shared
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isAuthenticated = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            
            if isAuthenticated {
                VStack {
                    // Header
                    HStack {
                        StandardIconButton(icon: "chevron.left", action: {
                            presentationMode.wrappedValue.dismiss()
                        })
                        
                        Text("Private Folder")
                            .font(.system(size: AppDesign.Icons.headerSize, weight: .bold))
                            .foregroundColor(.homeTextPrimary)
                        
                        Spacer()
                        
                        Button(action: {
                             // Lock action
                             isAuthenticated = false
                             authService.lock()
                        }) {
                            Image(systemName: "lock.fill")
                                .appIconStyle(size: AppDesign.Icons.toolbarSize, weight: .bold, color: .red)
                                .padding()
                        }
                    }
                    
                    // Private Content (Mocked as empty or specific items)
                    // In a real app, this would filter for 'isPrivate' flag
                    GeometryReader { geometry in
                        let isLandscape = geometry.size.width > geometry.size.height
                        let currentWidth = geometry.size.width
                        
                        ScrollView {
                            LazyVGrid(columns: GridLayout.gridColumns(isLandscape: isLandscape), spacing: 12) {
                                // Placeholder: showing same videos but pretending they are secure
                                // In real implementation: viewModel.privateVideos
                                ForEach(viewModel.videos.prefix(3)) { video in
                                    Button(action: {
                                        viewModel.playingVideo = video
                                    }) {
                                        VideoCardView(video: video, viewModel: viewModel, itemSize: GridLayout.itemSize(for: currentWidth, isLandscape: isLandscape))
                                            .overlay(
                                                Image(systemName: "lock.shield.fill")
                                                    .foregroundColor(.yellow)
                                                    .padding(4),
                                                alignment: .topLeading
                                            )
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "lock.circle.fill")
                        .appSecondaryIconStyle(size: 80, color: .homeTextSecondary)
                    
                    Text("Private Folder Locked")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Use FaceID/TouchID to access secure videos.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        authenticate()
                    }) {
                        Text("Unlock Folder")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 200)
                            .background(Color.homeAccent)
                            .cornerRadius(12)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            authenticate()
        }
    }
    
    private func authenticate() {
        authService.authenticate { success in
            self.isAuthenticated = success
        }
    }
}
