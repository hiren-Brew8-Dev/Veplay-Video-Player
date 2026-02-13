import SwiftUI
import AVFoundation
import CoreData
import GoogleCast

@main
struct VideoPlayerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Use CDManager shared instance
    let cdManager = CDManager.shared
    
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted = false
    @AppStorage("useFaceID") private var useFaceID = false
    @StateObject private var authService = BiometricAuthService.shared
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var ratingViewModel = RatingFlowViewModel.shared
    
    init() {
        configureAudioSession()
    }
    
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if showSplash {
                    SplashView()
                        .transition(.opacity)
                } else {
                    if !isOnboardingCompleted {
                        NavigationStack(path: $navigationManager.path) {
                            Onboarding1View()
                                .navigationDestination(for: NavigationDestination.self) { destination in
                                    switch destination {
                                    case .onboarding1: Onboarding1View()
                                    case .onboarding2: Onboarding2View()
                                    case .onboarding3: Onboarding3View()
                                    case .onboarding4: Onboarding4View()
                                    case .thanksForDownloading: ThanksForDownloadingView()
                                    case .rating: RatingView()
                                    case .dashboard: DashboardView()
                                    }
                                }
                        }
                    } else {
                        DashboardView()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .environment(\.managedObjectContext, cdManager.container.viewContext)
            .environmentObject(navigationManager)
            .environmentObject(ratingViewModel)
            .blur(radius: (useFaceID && !authService.isUnlocked) ? 15 : 0)
            .animation(.spring(), value: authService.isUnlocked)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                     if useFaceID && !authService.isUnlocked {
                         authenticate()
                     }
                } else if newPhase == .background {
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

class AppDelegate: NSObject, UIApplicationDelegate, GCKLoggerDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        GCKCastContext.setSharedInstanceWith(options)
        
        // Enable logging for debug
        GCKLogger.sharedInstance().delegate = self
        
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    
    // MARK: - GCKLoggerDelegate
    func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
        // print("GCK: \(message)")
    }
}
