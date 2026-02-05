import SwiftUI

struct MusicView: View {
    var body: some View {
        // NavigationView removed
        ZStack {
            Color.themeBackground.edgesIgnoringSafeArea(.all)
            VStack {
                Image(systemName: "music.note.list")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                Text("No Music Found")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.top)
                Text("Import music to start listening")
                    .foregroundColor(.gray)
            }
        }
    }
}
