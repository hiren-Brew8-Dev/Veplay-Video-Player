import SwiftUI
import AVFoundation
import CoreData
import GoogleCast
import Firebase

@main
struct VideoPlayerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    // Use CDManager shared instance
    let cdManager = CDManager.shared
    
    init() {
        FirebaseApp.configure()
        configureAudioSession()
    }
    
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var navigationManager = NavigationManager()
    @StateObject private var ratingViewModel = RatingFlowViewModel.shared
    @StateObject private var authService = BiometricAuthService.shared
    @AppStorage("useFaceID") private var useFaceID = false

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationManager.path) {
                SplashView()
                    .navigationDestination(for: NavigationDestination.self) { destination in
                        switch destination {
                        case .onboarding1: Onboarding1View()
                        case .onboarding2: Onboarding2View()
                        case .onboarding3: Onboarding3View()
                        case .onboarding4: Onboarding4View()
                        case .thanksForDownloading: ThanksForDownloadingView()
                        case .paywall: PaywallView()
                            .navigationBarHidden(true)
                        case .rating: RatingView()
                        case .dashboard: DashboardView()
                        case .settings: SettingsView()
                            .navigationBarHidden(true)
                        case .allFolders: FolderSectionView(viewModel: DashboardViewModel()) // Note: FolderSectionView needs a viewModel
                        case .folderDetail(let folder): FolderDetailView(initialFolder: folder, viewModel: DashboardViewModel())
                        case .search(let title, let videos): SearchView(viewModel: DashboardViewModel(), contextTitle: title, initialVideos: videos)
                        }
                    }
            }
            .preferredColorScheme(.dark)
            .environment(\.managedObjectContext, cdManager.container.viewContext)
            .environmentObject(navigationManager)
            .environmentObject(ratingViewModel)
            .blur(radius: (useFaceID && !authService.isUnlocked) ? 15 : 0)
            .animation(.spring(), value: authService.isUnlocked)
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
            // Handle result if needed
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
        
        GCKLogger.sharedInstance().delegate = self
        
        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    
    func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
    }
}
