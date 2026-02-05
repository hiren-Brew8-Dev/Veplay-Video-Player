import SwiftUI

struct PrivateFolderView: View {
    @StateObject private var authService = BiometricAuthService.shared
    @ObservedObject var viewModel: DashboardViewModel
    @State private var isAuthenticated = false
    @Environment(\.presentationMode) var presentationMode
    
    // Columns for grid
    private let columns = GridLayout.gridColumns
    
    var body: some View {
        ZStack {
            Color.themeBackground.edgesIgnoringSafeArea(.all)
            
            if isAuthenticated {
                VStack {
                    // Header
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                             Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding()
                        }
                        
                        Text("Private Folder")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                             // Lock action
                             isAuthenticated = false
                             authService.lock()
                        }) {
                            Image(systemName: "lock.fill")
                                .font(.title2)
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                    
                    // Private Content (Mocked as empty or specific items)
                    // In a real app, this would filter for 'isPrivate' flag
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            // Placeholder: showing same videos but pretending they are secure
                            // In real implementation: viewModel.privateVideos
                            ForEach(viewModel.videos.prefix(3)) { video in
                                Button(action: {
                                    viewModel.playingVideo = video
                                }) {
                                    VideoCardView(video: video, viewModel: viewModel)
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
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                    
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
                            .background(Color.blue)
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
