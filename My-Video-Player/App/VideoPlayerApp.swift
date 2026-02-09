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
                    AppLockView(onUnlock: authenticate)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .animation(.spring(), value: authService.isUnlocked)
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
