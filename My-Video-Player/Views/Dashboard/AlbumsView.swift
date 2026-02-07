import SwiftUI

struct AlbumsView: View {
    let folders: [Folder]
    @ObservedObject var viewModel: DashboardViewModel
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                HStack {
                    StandardIconButton(icon: "chevron.left", action: {
                        presentationMode.wrappedValue.dismiss()
                    })
                    
                    Spacer()
                    
                    Text("Albums")
                        .font(.system(size: AppDesign.Icons.headerSize, weight: .bold))
                        .foregroundColor(.homeTextPrimary)
                    
                    Spacer()
                    
                    // Placeholder for balance
                    StandardIconButton(icon: "chevron.left", color: .clear, bg: .clear, action: {})
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
                .background(Color.homeBackground)
                
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
