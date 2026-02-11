import Foundation
import GoogleCast
import Combine

class GoogleCastManager: NSObject, ObservableObject, GCKSessionManagerListener, GCKLoggerDelegate, GCKDiscoveryManagerListener {
    static let shared = GoogleCastManager()
    
    @Published var devices: [GCKDevice] = []
    @Published var currentSession: GCKCastSession?
    @Published var isConnected = false
    @Published var mediaStatus: GCKMediaStatus?
    @Published var currentMediaTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    
    private let context: GCKCastContext
    private let discoveryManager: GCKDiscoveryManager
    private let sessionManager: GCKSessionManager
    
    override init() {
        self.context = GCKCastContext.sharedInstance()
        self.discoveryManager = context.discoveryManager
        self.sessionManager = context.sessionManager
        super.init()
        
        setupManager()
    }
    
    func setupManager() {
        // Logging
        let logger = GCKLogger.sharedInstance()
        logger.delegate = self
        
        // Listeners
        discoveryManager.add(self)
        sessionManager.add(self)
        
        // Start discovery if permission granted? 
        // Google Cast handles this based on passive scan setting, but we can check.
        // Usually, calling discoveryManager.startDiscovery() is deprecated in favor of just observing.
        // It starts automatically when discoveryManager.passiveScan = false (active) or true.
        // We set passiveScan to false when "device picker" is open, but usually context manages.
        // However, we want to populate our OWN list.
        
        updateDevices()
        
        // Check current session
        if let session = sessionManager.currentCastSession {
            self.currentSession = session
            self.isConnected = true
        }
    }
    
    // MARK: - Discovery
    
    func startDiscovery() {
        // Setting passiveScan to false triggers active discovery (mdns queries)
        // Usually safer to rely on GCKCastContext's default behavior, but for custom UI:
        discoveryManager.passiveScan = false 
        updateDevices()
    }
    
    func stopDiscovery() {
        discoveryManager.passiveScan = true
    }
    
    private func updateDevices() {
        var newDevices: [GCKDevice] = []
        for i in 0..<discoveryManager.deviceCount {
            let device = discoveryManager.device(at: i)
            newDevices.append(device)
        }
        DispatchQueue.main.async {
            self.devices = newDevices
        }
    }
    
    // MARK: - GCKDiscoveryManagerListener
    
    func didStartDiscovery(forDeviceCategory category: String) {
        print("GoogleCast: Started discovery")
    }
    
    func didInsert(_ device: GCKDevice, at index: UInt) {
        updateDevices()
    }
    
    func didRemove(_ device: GCKDevice, at index: UInt) {
        updateDevices()
    }
    
    func didUpdate(_ device: GCKDevice, at index: UInt, andMoveTo newIndex: UInt) {
        updateDevices()
    }
    
    func didUpdate(_ device: GCKDevice, at index: UInt) {
        updateDevices()
    }
    
    // MARK: - Connection
    
    func connect(to device: GCKDevice) {
        sessionManager.endSession() // End current if any
        sessionManager.startSession(with: device)
    }
    
    func disconnect() {
        sessionManager.endSession()
    }
    
    // MARK: - GCKSessionManagerListener
    
    func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        print("GoogleCast: Session started with \(session.device.friendlyName ?? "Unknown")")
        DispatchQueue.main.async {
            self.currentSession = session as? GCKCastSession
            self.isConnected = true
        }
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        print("GoogleCast: Session ended. Error: \(String(describing: error))")
        DispatchQueue.main.async {
            self.currentSession = nil
            self.isConnected = false
            self.mediaStatus = nil
        }
    }
    
    func sessionManager(_ sessionManager: GCKSessionManager, didFailToStart session: GCKSession, withError error: Error) {
        print("GoogleCast: Session failed to start: \(error)")
        DispatchQueue.main.async {
            self.currentSession = nil
            self.isConnected = false
        }
    }
    
    // MARK: - Casting Media
    
    func loadMedia(url: URL, title: String? = nil, subtitle: String? = nil, posterURL: URL? = nil, contentType: String = "video/mp4", startTime: TimeInterval = 0) {
        guard let session = currentSession else { return }
        
        let metadata = GCKMediaMetadata(metadataType: .movie)
        if let title = title {
            metadata.setString(title, forKey: kGCKMetadataKeyTitle)
        }
        if let subtitle = subtitle {
            metadata.setString(subtitle, forKey: kGCKMetadataKeySubtitle)
        }
        
        if let posterURL = posterURL {
            metadata.addImage(GCKImage(url: posterURL, width: 480, height: 720))
        }
        
        let mediaInfoBuilder = GCKMediaInformationBuilder(contentURL: url)
        mediaInfoBuilder.streamType = .buffered
        mediaInfoBuilder.contentType = contentType
        mediaInfoBuilder.metadata = metadata
        
        let mediaInfo = mediaInfoBuilder.build()
        
        let loadOptions = GCKMediaLoadOptions()
        loadOptions.playPosition = startTime
        loadOptions.autoplay = true
        
        session.remoteMediaClient?.loadMedia(mediaInfo, with: loadOptions)
    }
    
    func pause() {
        currentSession?.remoteMediaClient?.pause()
    }
    
    func play() {
        currentSession?.remoteMediaClient?.play()
    }
    
    func seek(to time: TimeInterval) {
        let seekOptions = GCKMediaSeekOptions()
        seekOptions.interval = time
        seekOptions.resumeState = .play
        currentSession?.remoteMediaClient?.seek(with: seekOptions)
    }

    // MARK: - Logger
    
    func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
        // Optional: Filter logs
        // print("GCK: \(function) - \(message)")
    }
}
