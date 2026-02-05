import SwiftUI
import AVFoundation
import CoreData

@main
struct VideoPlayerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Use CDManager shared instance
    let cdManager = CDManager.shared
    
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("useFaceID") private var useFaceID = false
    @StateObject private var authService = BiometricAuthService.shared
    
    init() {
        configureAudioSession()
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                DashboardView()
                    .preferredColorScheme(.dark)
                    .environment(\.managedObjectContext, cdManager.container.viewContext)
                    .blur(radius: (useFaceID && !authService.isUnlocked) ? 15 : 0) // Blur content when locked
                
                if useFaceID && !authService.isUnlocked {
                    // Lock Screen Overlay
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 20) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text("App Locked")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Button(action: {
                            authenticate()
                        }) {
                            HStack {
                                Image(systemName: "faceid")
                                Text("Unlock with Face ID")
                            }
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                     // Try to auth if needed
                     if useFaceID && !authService.isUnlocked {
                         authenticate()
                     }
                } else if newPhase == .background {
                    // Lock on background
                    if useFaceID {
                        authService.isUnlocked = false
                    }
                }
            }
        }
    }
    
    private func authenticate() {
        authService.authenticate { success in
            // Handle result if needed, currently service updates published property
        }
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}
