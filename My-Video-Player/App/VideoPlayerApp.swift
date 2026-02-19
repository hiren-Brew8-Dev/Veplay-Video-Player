import SwiftUI
import AVFoundation
import CoreData
import GoogleCast
import GoogleCast
import Firebase
import PhotosUI

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
    @State private var selectedPhotoItems = [PhotosPickerItem]()

    @AppStorage("useFaceID") private var useFaceID = false
    
    // Initialize SubscriptionStore early
    private let subscriptionStore = SubscriptionStore.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                if navigationManager.isDashboardRoot {
                    DashboardView()
                        .environmentObject(dashboardViewModel)
                } else {
                    NavigationStack(path: $navigationManager.path) {
                        SplashView()
                            .navigationDestination(for: NavigationDestination.self) { destination in
                                switch destination {
                                case .onboarding1: Onboarding1View()
                                case .onboarding2: Onboarding2View()
                                case .onboarding3: Onboarding3View()
                                case .onboarding4: Onboarding4View()
                                case .onboarding5: Onboarding5View()
                                case .photoLibraryAccess: PhotoLibraryAccessView()
                                    .environmentObject(dashboardViewModel)
                                case .thanksForDownloading: ThanksForDownloadingView()
                                    .environmentObject(dashboardViewModel)
                                case .paywall(let isFromOnboarding): PaywallView(isFromOnboarding: isFromOnboarding)
                                    .hideNavigationBar()
                                case .rating: RatingView()
                                case .dashboard: EmptyView() // Handled by root switching
                                case .settings: SettingsView()
                                    .environmentObject(dashboardViewModel)
                                    .hideNavigationBar()
                                case .allFolders, .folderDetail, .search:
                                    EmptyView()
                                }
                            }
                    }
                }
                
                // Global Action Sheet Overlay
                if dashboardViewModel.showActionSheet {
                    ActionSheetOverlay(viewModel: dashboardViewModel)
                }
                
                // Global Conflict Resolution Overlay for Paste Operations
                ConflictResolutionOverlay(viewModel: dashboardViewModel)
                
                // Global Importing Overlay
                ImportingOverlay(viewModel: dashboardViewModel)
            }
            .preferredColorScheme(.dark)
            .environment(\.managedObjectContext, cdManager.container.viewContext)
            .environmentObject(navigationManager)
            .environmentObject(ratingViewModel)
            .environmentObject(dashboardViewModel)
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
            // MARK: - Global Import Handlers
            .fileImporter(
                isPresented: $dashboardViewModel.showFileImporter,
                allowedContentTypes: [.movie, .video, .quickTimeMovie, .mpeg4Movie, .mpeg, .avi, .item],
                allowsMultipleSelection: true
            ) { result in
                dashboardViewModel.handleFileImport(result)
            }
            .photosPicker(
                isPresented: $dashboardViewModel.showPhotoPicker,
                selection: $selectedPhotoItems,
                matching: .videos
            )
            .onChange(of: selectedPhotoItems) { oldItems, newItems in
                if !newItems.isEmpty {
                    dashboardViewModel.handlePhotoImport(newItems)
                    selectedPhotoItems.removeAll()
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
