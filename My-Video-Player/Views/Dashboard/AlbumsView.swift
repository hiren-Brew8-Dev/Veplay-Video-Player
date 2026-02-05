import SwiftUI

struct AlbumsView: View {
    let folders: [Folder]
    @ObservedObject var viewModel: DashboardViewModel
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.themeBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
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
                    
                    Text("Albums")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Placeholder for balance
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.clear)
                        .padding(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.themeBackground)
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 15),
                        GridItem(.flexible(), spacing: 15),
                        GridItem(.flexible(), spacing: 15)
                    ], spacing: 15) {
                        ForEach(folders) { folder in
                            NavigationLink(destination: FolderDetailView(initialFolder: folder, viewModel: viewModel)) {
                                FolderCardView(folder: folder)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, 80)
                }
            }
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}
