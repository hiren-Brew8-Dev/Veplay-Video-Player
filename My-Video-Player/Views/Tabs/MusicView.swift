import SwiftUI

struct MusicView: View {
    var body: some View {
        // NavigationView removed
        ZStack {
            Color.homeBackground.edgesIgnoringSafeArea(.all)
            VStack {
                Image(systemName: "music.note.list")
                    .appSecondaryIconStyle(size: 80, color: .homeTextSecondary)
                Text("No Music Found")
                    .font(.title2)
                    .foregroundColor(.homeTextPrimary)
                    .padding(.top)
                Text("Import music to start listening")
                    .foregroundColor(.homeTextSecondary)
            }
        }
    }
}
