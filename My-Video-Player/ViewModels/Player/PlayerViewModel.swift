import Foundation
import AVFoundation
import MobileVLCKit
import Combine
import Photos
import MediaPlayer
import SwiftUI
import UIKit

class PlayerViewModel: NSObject, ObservableObject {
    @MainActor @Published var player: AVPlayer?
    @MainActor @Published var vlcPlayer: VLCMediaPlayer?
    @MainActor @Published var isVLC: Bool = false
    @MainActor @Published var isPlaying: Bool = false
    @MainActor @Published var currentTime: Double = 0
    @MainActor @Published var isSeeking: Bool = false
    @MainActor @Published var aspectRatio: VideoAspectRatio = .fit {
        didSet {
            updateAspectRatio()
        }
    }
    @MainActor @Published var repeatMode: RepeatMode = .off
    @MainActor @Published var didFinishPlayback: Bool = false
    @MainActor @Published var shouldDismissPlayer: Bool = false
    
    @MainActor @Published var duration: Double = 0
    @MainActor @Published var isControlsVisible: Bool = true
    @MainActor @Published var isLocked: Bool = false
    @MainActor @Published var playbackSpeed: Float = 1.0
    @MainActor @Published var isExternalPlaybackActive: Bool = false
    @MainActor @Published var isSeekUIActive: Bool = false
    @MainActor @Published var isSeekForward: Bool = true
    
    
    enum ActiveMenu {
        case none
        case aspectRatio
        case playbackSpeed
    }
    @MainActor @Published var activeMenu: ActiveMenu = .none
    
    // Internal state
    private var timeObserver: Any?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var externalPlaybackObserver: NSKeyValueObservation?
    private var videoId: String?
    @MainActor var videoTitle: String = ""
    @MainActor @Published var videoThumbnail: UIImage?
    
    @MainActor @Published var currentTimeString: String = "00:00"
    @MainActor @Published var totalDurationString: String = "00:00"
    
    // VLC Seek Synchronization
    @MainActor private var lastIntendedSeekPosition: Double? = nil
    
    // Rotation & Brightness
    private var initialBrightness: CGFloat?
    @MainActor @Published var showBrightnessUI: Bool = false
    @MainActor @Published var currentBrightness: Float = Float(UIScreen.main.brightness)
    private var brightnessHideWorkItem: DispatchWorkItem?
    
    // PiP
    @MainActor @Published var isPiPActive: Bool = false
    @MainActor @Published var showPiPError: Bool = false
    private var toastTask: Task<Void, Never>?
    
    // Size tracking for Aspect Ratio
    @MainActor private var lastKnownViewSize: CGSize? = nil
    
    // Subtitles/Audio Selection
    @MainActor @Published var availableSubtitles: [String] = []
    @MainActor @Published var selectedSubtitleIndex: Int = -1
    
    // Sleep Timer
    enum SleepTimerMode: Equatable {
        case off
        case duration(TimeInterval)
        case endOfTrack
    }
    
    @MainActor @Published var sleepTimerMode: SleepTimerMode = .off
    @MainActor @Published var sleepTimerRemainingString: String? = nil
    @MainActor @Published var sleepTimerOriginalDuration: TimeInterval? = nil // To track selection highlighting
    
    var isSleepTimerActive: Bool {
        if case .off = sleepTimerMode { return false }
        return true
    }
    
    private var sleepTimer: Timer?
    
    @MainActor @Published var availableAudioTracks: [String] = []
    @MainActor @Published var selectedAudioTrackIndex: Int = -1
   
    @MainActor @Published var audioDelay: Double = 0.0
    
    // Queue Management
    @MainActor @Published var playlist: [VideoItem] = []
    @MainActor @Published var currentIndex: Int = 0
    @MainActor @Published var autoPlayNext: Bool = true
    
    // Computed property to get the consistent ID string used for persistence
    private var currentPersistenceId: String? {
        if let video = currentVideoItem {
             return video.asset?.localIdentifier ?? video.url?.absoluteString ?? video.title
        }
        return nil
    }
    
    // Sharing & Snapshot
    // Sharing & Snapshot
    @MainActor @Published var currentVideoItem: VideoItem?
    @MainActor @Published var currentVideoURL: URL?
    @MainActor var videoURL: URL? { currentVideoURL }
    @MainActor @Published var showSnapshotSavedToast: Bool = false
    
    // Bookmarks
    @MainActor @Published var bookmarks: [BookmarkItem] = []
    @MainActor @Published var showBookmarkSheet: Bool = false
        
    // Skip/Seek Tracking
    @MainActor @Published var accumulatedSkipAmount: Double = 0
    private var lastSeekForward: Bool? = nil
    private var skipResetTask: Task<Void, Never>?
    private var seekAnchorTime: Double = 0
    
    // Subtitles Support
    let subtitleManager = SubtitleManager()
    private var embeddedSubtitleOptions: [AVMediaSelectionOption] = []
    private var embeddedAudioOptions: [AVMediaSelectionOption] = []
    private var vlcSubtitleMapping: [String: Int32] = [:]
    private var vlcAudioMapping: [String: Int32] = [:]
    
    // Audio Engine for AVPlayer audio delay
    // NOTE: AVPlayerItemAudioOutput is not available in iOS SDK
    // Audio delay only works with VLC player
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    // private var audioOutput: AVPlayerItemAudioOutput?
    private var audioDelayBuffer: [AVAudioPCMBuffer] = []
    private var currentAudioDelayMs: Double = 0
    
    @MainActor
    var currentAudioTrackName: String {
        guard selectedAudioTrackIndex >= 0 && selectedAudioTrackIndex < availableAudioTracks.count else {
            return "Default"
        }
        return availableAudioTracks[selectedAudioTrackIndex]
    }
    
    @MainActor
    var currentSubtitleName: String {
        if selectedSubtitleIndex >= 0 && selectedSubtitleIndex < availableSubtitles.count {
            return availableSubtitles[selectedSubtitleIndex]
        }
        return "None"
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // Seek tracking
    private var seekRequestID: Int = 0
    private var isLifecycleSetup = false
    
    enum VideoAspectRatio: String, CaseIterable {
        case fit = "Fit to Screen"
        case fill = "Fill Screen" // Zoom
        case stretch = "Stretch"
        case original = "Original"
        case sixteenByNine = "16:9"
        case fourByThree = "4:3"
        case sixteenByTen = "16:10"

        var gravity: AVLayerVideoGravity {
            switch self {
            case .fit, .original: return .resizeAspect
            case .fill: return .resizeAspectFill
            case .stretch, .sixteenByNine, .fourByThree, .sixteenByTen: return .resize
            }
        }

        var ratioValue: CGFloat? {
            switch self {
            case .sixteenByNine: return 16.0 / 9.0
            case .fourByThree: return 4.0 / 3.0
            case .sixteenByTen: return 16.0 / 10.0
            default: return nil
            }
        }
        
        var isUnconstrained: Bool {
            switch self {
            case .fit, .fill, .stretch, .original: return true
            default: return false
            }
        }
        
        var shortLabel: String {
            switch self {
            case .fit: return "Fit"
            case .fill: return "Fill"
            case .stretch: return "Stretch"
            case .original: return "Original"
            case .sixteenByNine: return "16:9"
            case .fourByThree: return "4:3"
            case .sixteenByTen: return "16:10"
            }
        }
        
        var next: VideoAspectRatio {
            // Defined Cycle: Fit -> Fill -> Stretch -> Original -> 16:9 -> 4:3 -> 16:10 -> Fit
            switch self {
            case .fit: return .fill
            case .fill: return .stretch
            case .stretch: return .original
            case .original: return .sixteenByNine
            case .sixteenByNine: return .fourByThree
            case .fourByThree: return .sixteenByTen
            case .sixteenByTen: return .fit
            }
        }
    }
    
    enum RepeatMode: String, CaseIterable {
        case off = "Repeat Off"
        case one = "Repeat One"
        case all = "Repeat All"
    }
    
    enum PlayingMode: String, CaseIterable {
        case playInOrder = "Play in Order"
        case shufflePlay = "Shuffle Play"
        case repeatOne = "Repeat Ones"
        case oneTrack = "One Track"
        
        var iconName: String {
            switch self {
            case .playInOrder: return "text.append"
            case .shufflePlay: return "shuffle"
            case .repeatOne: return "repeat.1"
            case .oneTrack: return "play.square"
            }
        }
    }
    
    @MainActor @Published var playingMode: PlayingMode = .playInOrder

    @MainActor
    func performDoubleTapSeek(forward: Bool) {
        let baseSkip: Double = 10
        
        // 1. Determine if we continue an existing sequence or start a new one
        // If UI isn't active, OR direction changed, we start fresh sequence from CURRENT playback time
        if !isSeekUIActive || lastSeekForward != forward {
            seekAnchorTime = currentTime
            accumulatedSkipAmount = 0
            lastSeekForward = forward
            isSeekUIActive = true
        }
        
        // 2. Increment the skip amount
        accumulatedSkipAmount += baseSkip
        
        // 3. Calculate target from the starting anchor
        var targetTime = forward ? (seekAnchorTime + accumulatedSkipAmount) : (seekAnchorTime - accumulatedSkipAmount)
        
        // 4. Boundary checks
        if duration > 0 {
            // "if the available seconds are < 10 secs the show that second"
            // We clamp to boundaries
            targetTime = max(0, min(targetTime, duration))
        } else {
            targetTime = max(0, targetTime)
        }
        
        // 5. Update display amount to what we actually skipped
        // This ensures if we hit the end/start, it shows the actual remaining distance
        accumulatedSkipAmount = abs(targetTime - seekAnchorTime)
        
        // 6. Seek
        seek(to: targetTime)
        
        // 7. Reset the 0.8s hide timer
        showSeekUI(forward: forward)
    }

    @MainActor
    func showSeekUI(forward: Bool) {
        self.isSeekForward = forward
        self.isSeekUIActive = true
        
        skipResetTask?.cancel()
        skipResetTask = Task {
            // Updated to 0.8s as requested
            try? await Task.sleep(nanoseconds: 800_000_000) 
            
            if !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.isSeekUIActive = false
                    }
                    
                    // Cleanup anchor state after fade out completes
                    Task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        if !Task.isCancelled && !self.isSeekUIActive {
                            await MainActor.run {
                                self.accumulatedSkipAmount = 0
                                self.lastSeekForward = nil
                                self.seekAnchorTime = 0
                            }
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
    func setBrightness(_ value: Float) {
        let clamped = min(max(value, 0.0), 1.0)
        currentBrightness = clamped
        UIScreen.main.brightness = CGFloat(clamped)
        triggerBrightnessUI()
    }
    
    @MainActor
    func triggerBrightnessUI() {
        brightnessHideWorkItem?.cancel()
        
        if !showBrightnessUI {
            showBrightnessUI = true
        }
        
        let task = DispatchWorkItem { [weak self] in
            self?.hideBrightnessUI()
        }
        
        brightnessHideWorkItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: task)
    }
    
    func hideBrightnessUI() {
        brightnessHideWorkItem?.cancel()
        if showBrightnessUI {
            showBrightnessUI = false
        }
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        Task { @MainActor in
            setupSubtitleObservation()
            setupLifecycleObservers()
        }
    }
    
    private func setupSubtitleObservation() {
        subtitleManager.$selectedTrackIndex
            .sink { [weak self] index in
                self?.handleSubtitleSelection(index)
            }
            .store(in: &cancellables)
        
        subtitleManager.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
            
        subtitleManager.$offsetDelay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] delay in
                guard let self = self, let player = self.vlcPlayer, self.isVLC else { return }
                player.currentVideoSubTitleDelay = Int(delay * 1_000_000)
            }
            .store(in: &cancellables)
            
        $audioDelay
            .receive(on: DispatchQueue.main)
            .sink { [weak self] delay in
                guard let self = self else { return }
                
                if self.isVLC, let player = self.vlcPlayer {
                    // VLC audio delay is in microseconds. A positive value delays audio (audio appears later).
                    player.currentAudioPlaybackDelay = Int(delay * 1_000_000)
                } else if !self.isVLC, let playerItem = self.player?.currentItem {
                    // AVPlayer audio delay implementation
                    self.applyAudioDelayToAVPlayer(delay, playerItem: playerItem)
                }
            }
            .store(in: &cancellables)
    }
    
    // ... setup ...
    
    @MainActor
    func setupPlayer(with video: VideoItem, title: String? = nil, playlist: [VideoItem] = [], autoPlay: Bool = true) {
        self.isVLC = false
        self.playlist = playlist
        if let index = playlist.firstIndex(where: { $0.id == video.id }) {
            self.currentIndex = index
        }
        
        self.currentVideoItem = video
        self.videoTitle = title ?? video.title
        
        // Save initial brightness
        self.initialBrightness = UIScreen.main.brightness
        self.currentBrightness = Float(UIScreen.main.brightness)
        
        self.videoId = video.id.uuidString
        self.loadBookmarks()
        self.subtitleManager.clear()
        
        // Clear VLC-specific track mappings for fresh state
        self.vlcSubtitleMapping.removeAll()
        self.vlcAudioMapping.removeAll()
        self.availableAudioTracks.removeAll()
        self.availableSubtitles.removeAll()
        self.embeddedSubtitleOptions.removeAll()
        self.embeddedAudioOptions.removeAll()
        self.audioDelay = 0.0
        
        // Configure Audio Session for Background Playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        setupRemoteTransportControls()
        
        // Log to History (Only Photo Album Videos)
        if video.asset != nil {
            CDManager.shared.saveToHistory(video: video)
        }
        
        // Reset progress and state for new video (prevents flicker/stale data)
        self.currentTime = 0
        self.duration = 0
        self.currentTimeString = "00:00"
        self.totalDurationString = "00:00"
        self.isPlaying = autoPlay
        self.isSeeking = false
        
        // Comprehensive cleanup of previous player instances
        if let oldVLC = vlcPlayer {
            oldVLC.delegate = nil // Prevents callbacks during cleanup
            oldVLC.stop()
            vlcPlayer = nil
        }
        
        if let oldAV = player {
            oldAV.pause()
            if let obs = timeObserver {
                oldAV.removeTimeObserver(obs)
                timeObserver = nil
            }
            // Invalidate KVO observers
            timeControlStatusObserver?.invalidate()
            timeControlStatusObserver = nil
            externalPlaybackObserver?.invalidate()
            externalPlaybackObserver = nil
            
            player = nil
        }

        // Check for VLC Types OR force VLC if desired (User Request: Native Subtitle View "Any How")
        // Since AVPlayer cannot render external SRTs natively (without custom overlay),
        // and the user explicitly rejected the custom overlay ("not want custom..."),
        // we must fallback to VLC for everything to guarantee native subtitle support.
        if let url = video.url {
            setupVLCPlayer(url: url, autoPlay: autoPlay)
            return
        }
        
        // Only if no URL (PHAsset-only without URL resolved yet?), use AVPlayer temporarily
        // But usually video.url is resolved. If not, we fall through.
        // Wait, standard setup handles PHAsset request.
        // We can convert PHAsset to URL? Usually PHAssets are handled by requestAVAsset.
        
        // If we really want to force VLC for PHAssets too, we need the URL.
        // Usually `video.url` is nil for PHAssets in this model? Let's check.
        // If video.url is nil, we proceed to AVPlayer.
        // However, user specifically mentioned "load subtitles" which usually implies external files or MKV.
        // MKV/AVI etc are already handled by isVLCFormat.
        // The issue is likely MP4/MOV files playing in AVPlayer not showing correct subs.
        
        // Correct approach: Try to obtain URL for AVAsset if possible and use VLC.
        // For now, let's broaden the VLC check.
        if let url = video.url {
             setupVLCPlayer(url: url, autoPlay: autoPlay)
             return
        }
        
        // Standard AVPlayer Setup
        if let asset = video.asset {
            let options = PHVideoRequestOptions()
            options.version = .original
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
                guard let self = self, let avAsset = avAsset else { return }
                Task { @MainActor in
                    if let urlAsset = avAsset as? AVURLAsset {
                        self.currentVideoURL = urlAsset.url
                    }
                    self.configurePlayer(asset: avAsset, autoPlay: autoPlay)
                }
            }
        } else if let url = video.url {
             // Standard URL (MP4 etc)
             self.currentVideoURL = url
             let asset = AVURLAsset(url: url)
             self.configurePlayer(asset: asset, autoPlay: autoPlay)
        }
        
        generateThumbnail(for: video)
    }

    @MainActor
    func playNext(forceAutoPlay: Bool = false) {
        if playingMode == .shufflePlay && playlist.count > 1 {
            var newIndex = Int.random(in: 0..<playlist.count)
            while newIndex == currentIndex {
                newIndex = Int.random(in: 0..<playlist.count)
            }
            selectFromQueue(at: newIndex, forceAutoPlay: forceAutoPlay || self.isPlaying)
            return
        }
        
        guard currentIndex + 1 < playlist.count else { return }
        let shouldAutoPlay = forceAutoPlay || self.isPlaying // Consistency: preserve current state unless forced
        currentIndex += 1
        let nextVideo = playlist[currentIndex]
        setupPlayer(with: nextVideo, playlist: playlist, autoPlay: shouldAutoPlay)
    }

    @MainActor
    func playPrevious(forceAutoPlay: Bool = false) {
        guard currentIndex > 0 else { return }
        let shouldAutoPlay = forceAutoPlay || self.isPlaying // Consistency: preserve current state unless forced
        currentIndex -= 1
        let prevVideo = playlist[currentIndex]
        setupPlayer(with: prevVideo, playlist: playlist, autoPlay: shouldAutoPlay)
    }

    @MainActor
    func selectFromQueue(at index: Int, forceAutoPlay: Bool = false) {
        guard index >= 0 && index < playlist.count else { return }
        let shouldAutoPlay = forceAutoPlay || self.isPlaying // Preserve current play/pause state unless forced
        currentIndex = index
        let video = playlist[currentIndex]
        setupPlayer(with: video, playlist: playlist, autoPlay: shouldAutoPlay)
    }
    
    @MainActor
    func captureSnapshot(completion: @escaping (UIImage?) -> Void) {
        let handleImage: (UIImage?) -> Void = { [weak self] image in
            guard let self = self, let img = image else {
                completion(image)
                return
            }
            let processed = self.processSnapshot(img)
            completion(processed)
        }

        if isVLC {
            guard let player = vlcPlayer else {
                completion(nil)
                return
            }
            
            // VLC Snapshot
            let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
            // VLC saves to path
            player.saveVideoSnapshot(at: tmpFile.path, withWidth: 0, andHeight: 0)
            
            // Wait slightly for file to be written
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if let data = try? Data(contentsOf: tmpFile), let image = UIImage(data: data) {
                    handleImage(image)
                    try? FileManager.default.removeItem(at: tmpFile)
                } else {
                    handleImage(nil)
                }
            }
            
        } else {
            // AVPlayer Snapshot
            guard let asset = player?.currentItem?.asset else {
                completion(nil)
                return
            }
            
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
            
            let time = player?.currentTime() ?? .zero
            
            Task {
                do {
                    let image = try await generator.image(at: time).image
                    handleImage(UIImage(cgImage: image))
                } catch {
                    print("Snapshot error: \(error)")
                    handleImage(nil)
                }
            }
        }
    }
    
    // Process image to match player's visual aspect ratio
    private func processSnapshot(_ image: UIImage) -> UIImage {
        // If "Original" or "Fit", we return the full frame (standard behavior)
        if aspectRatio == .original || aspectRatio == .fit {
            return image
        }
        
        let targetRatio: CGFloat
        let isAvailableScreen = aspectRatio == .fill || aspectRatio == .stretch
        
        if isAvailableScreen {
             let screen = UIScreen.main.bounds.size
             targetRatio = screen.width / screen.height
        } else {
             targetRatio = aspectRatio.ratioValue ?? 1.0
        }
        
        let shouldCrop = (aspectRatio == .fill)
        
        if shouldCrop {
            // CROP LOGIC
            let imageSize = image.size
            let imageRatio = imageSize.width / imageSize.height
            var cropRect: CGRect?
            
            if abs(imageRatio - targetRatio) > 0.01 {
                if imageRatio > targetRatio {
                    // Image is wider than target: Crop width
                    let newWidth = floor(imageSize.height * targetRatio)
                    let xOffset = floor((imageSize.width - newWidth) / 2)
                    cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: imageSize.height)
                } else {
                    // Image is taller than target: Crop height
                    let newHeight = floor(imageSize.width / targetRatio)
                    let yOffset = floor((imageSize.height - newHeight) / 2)
                    cropRect = CGRect(x: 0, y: yOffset, width: imageSize.width, height: newHeight)
                }
            }
            
            if let rect = cropRect {
                // Ensure integral pixel alignment to avoid white lines/artifacts
                let integralRect = rect.integral
                
                // Ensure strict bounds to avoid 1px gaps
                let imageBounds = CGRect(origin: .zero, size: imageSize)
                let finalRect = integralRect.intersection(imageBounds)
                
                if let cgImage = image.cgImage?.cropping(to: finalRect) {
                    return UIImage(cgImage: cgImage)
                }
            }
            return image
            
        } else {
            // RESIZE LOGIC (Stretch / Fixed Ratio)
            // Note: For fixed ratios (like 4:3), if the source is not 4:3, '.resize' (Stretch) behavior means
            // we distort it to fit the 4:3 box. If we just wanted to FIT 4:3 with bars, we wouldn't be here (Fit).
            
            let imageSize = image.size
            
            // Calculate new dimensions to forcefully MATCH the target ratio
            // We usually keep the Height fixed (to maintain resolution) and strictly set Width
            let newWidth = floor(imageSize.height * targetRatio)
            let newSize = CGSize(width: newWidth, height: imageSize.height)
            
            // Use UIGraphicsImageRenderer for high quality resize
            let renderer = UIGraphicsImageRenderer(size: newSize)
            return renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
    }
    
    @MainActor
    func saveImageToPhotos(_ image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            if status == .authorized || status == .limited {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                Task { @MainActor in
                    self.showSnapshotSavedToast = true
                    // Hide toast after a delay
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    self.showSnapshotSavedToast = false
                }
            } else {
                print("Photo library access denied")
            }
        }
    }
    
    @MainActor
    func prepareVideoForSharing(completion: @escaping (URL?) -> Void) {
        // 1. Try direct URL from VideoItem
        if let video = currentVideoItem, let url = video.url {
            completion(url)
            return
        }
        
        // 2. Try URL from AVPlayer (if simple file)
        if let url = currentVideoURL {
             print("Sharing: Found simple AVPlayer URL: \(url)")
             completion(url)
             return
        }
        
        // 3. Try PHAsset Export (Library Video)
        if let video = currentVideoItem, let asset = video.asset {
            print("Sharing: Found PHAsset via currentVideoItem")
             let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
                if let urlAsset = avAsset as? AVURLAsset {
                    DispatchQueue.main.async {
                        completion(urlAsset.url)
                    }
                } else {
                    // Export Resource
                    let resources = PHAssetResource.assetResources(for: asset)
                    if let firstResource = resources.first {
                        let tempDir = FileManager.default.temporaryDirectory
                        let outputURL = tempDir.appendingPathComponent(firstResource.originalFilename)
                        
                        // If file already exists return it
                        if FileManager.default.fileExists(atPath: outputURL.path) {
                             DispatchQueue.main.async { completion(outputURL) }
                            return
                        }
                        
                        PHAssetResourceManager.default().writeData(for: firstResource, toFile: outputURL, options: nil) { error in
                             DispatchQueue.main.async {
                                if error == nil {
                                    completion(outputURL)
                                } else {
                                    print("Share Export Error: \(String(describing: error))")
                                    completion(nil)
                                }
                            }
                        }
                    } else {
                         DispatchQueue.main.async { completion(nil) }
                    }
                }
            }
            return
        }
        
        completion(nil)
    }
    
    // MARK: - Bookmark Management
    
    @MainActor
    func loadBookmarks() {
        guard let idString = currentPersistenceId else {
            self.bookmarks = []
            return
        }
        self.bookmarks = CDManager.shared.fetchBookmarks(for: idString)
    }
    
    @MainActor
    func addBookmark() {
        guard let idString = currentPersistenceId else { return }
        
        // Prevent duplicates (within 0.5s)
        if bookmarks.contains(where: { abs($0.time - currentTime) < 0.5 }) {
            return
        }
        
        // For VLC: Temporarily block time observer updates during bookmark save
        // This prevents VLC from reverting to old position after adding bookmark
        let wasSeekingBlocked = isSeeking
        if isVLC && !wasSeekingBlocked {
            isSeeking = true
        }
        
        // Generate Sequential Name
        let existingNumbers = bookmarks.compactMap { Int($0.name ?? "") }
        let nextNumber = (existingNumbers.max() ?? 0) + 1
        let newName = "\(nextNumber)"
        
        if let newBookmark = CDManager.shared.saveBookmark(videoIdString: idString, time: currentTime, name: newName) {
            // Optimistically update list
            self.bookmarks.append(newBookmark)
            
            // For VLC: Take a snapshot of the current frame for the bookmark list
            if isVLC, let uuid = newBookmark.id {
                takeVLCSnapshot(for: uuid)
            }
        }
        
        // Restore isSeeking state after a brief delay
        if isVLC && !wasSeekingBlocked {
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms - balanced protection
                await MainActor.run {
                    self.isSeeking = false
                }
            }
        }
    }
    
    @MainActor
    func toggleBookmark() {
        if let existing = bookmarks.first(where: { abs($0.time - currentTime) < 0.5 }) {
            deleteBookmark(existing)
        } else {
            addBookmark()
        }
    }
    
    @MainActor
    func deleteBookmark(_ item: BookmarkItem) {
        CDManager.shared.deleteBookmark(item)
        if let index = bookmarks.firstIndex(of: item) {
            bookmarks.remove(at: index)
        }
    }
    
    @MainActor
    func renameBookmark(_ item: BookmarkItem, newName: String) {
        CDManager.shared.updateBookmarkName(item, newName: newName)
        // Trigger UI update if needed (ObservedObject handles properties, but ensure list updates)
        objectWillChange.send() 
    }
    
    @MainActor
    func seekToBookmark(_ item: BookmarkItem) {
        seek(to: item.time)
    }
    
    @MainActor
    func seekToPreviousBookmark() {
        // Sort effectively (bookmarks are sorted on load/add)
        let sorted = bookmarks.sorted { $0.time < $1.time }
        if let prev = sorted.last(where: { $0.time < currentTime - 1.0 }) {
            seek(to: prev.time)
        }
    }
    
    @MainActor
    func seekToNextBookmark() {
        let sorted = bookmarks.sorted { $0.time < $1.time }
        if let next = sorted.first(where: { $0.time > currentTime + 1.0 }) {
            seek(to: next.time)
        }
    }
    
    @MainActor
    var hasPreviousBookmark: Bool {
        bookmarks.contains { $0.time < currentTime - 1.0 }
    }
    
    @MainActor
    var hasNextBookmark: Bool {
        bookmarks.contains { $0.time > currentTime + 1.0 }
    }
    
    @MainActor
    var isAtBookmark: Bool {
        bookmarks.contains { abs($0.time - currentTime) < 0.5 }
    }

    private func isVLCFormat(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let vlcExtensions = ["mkv", "avi", "wmv", "flv", "webm", "3gp", "vob", "mpg", "mpeg", "ts", "m2ts", "divx", "asf"]
        return vlcExtensions.contains(ext)
    }
    
    @MainActor
    private func setupVLCPlayer(url: URL, autoPlay: Bool = true) {
        // Initialize VLC Player
        self.isVLC = true
        self.vlcPlayer = VLCMediaPlayer()
        let media = VLCMedia(url: url)
        
        // Optimize caching for smoother start
        // :network-caching=300 (buffer for local network/files, helps smooth playback without huge delay)
        // :clock-jitter=0 (reduce sync jitter)
        // :clock-synchro=0 (ensure audio/video sync)
        media.addOptions([
            "network-caching": 300,
            "clock-jitter": 0,
            "clock-synchro": 0,
            "file-caching": 300
        ])
        
        self.currentVideoURL = url
        
        vlcPlayer?.media = media
        vlcPlayer?.delegate = self
        
        // Discover and add external subtitles BEFORE parsing
        discoverExternalSubtitles(for: url)
        
        // Start parsing immediately to get tracks instantly
        media.delegate = self
        media.parse() 
        
        // Restore progress
        if let vid = self.videoId, let savedTime = UserDefaults.standard.object(forKey: "resume_\(vid)") as? Double {
             self.currentTime = savedTime
             self.vlcPlayer?.time = VLCTime(int: Int32(savedTime * 1000))
        }
        
        if autoPlay {
             // Delay play slightly to allow view hierarchy to settle?
             // Or ensure it happens on next run loop
             DispatchQueue.main.async {
                 self.play()
             }
        } else {
            self.isPlaying = false
        }
        
        // Apply current aspect ratio
        updateVLCAspectRatio()
        
        // Setup time observer for subtitle updates
        setupVLCTimeObserver()
    }
    
    private func discoverExternalSubtitles(for videoUrl: URL) {
        let fileManager = FileManager.default
        let directoryUrl = videoUrl.deletingLastPathComponent()
        let videoName = videoUrl.deletingPathExtension().lastPathComponent
        
        do {
            let files = try fileManager.contentsOfDirectory(at: directoryUrl, includingPropertiesForKeys: nil)
            let srtFiles = files.filter { $0.pathExtension.lowercased() == "srt" }
            
            for srtUrl in srtFiles {
                let srtName = srtUrl.deletingPathExtension().lastPathComponent
                
                // Add if it matches video name or is likely related
                if srtName.localizedCaseInsensitiveContains(videoName) || srtFiles.count == 1 {
                    // For VLC, we can also add it as a playback slave for native rendering
                    vlcPlayer?.addPlaybackSlave(srtUrl, type: .subtitle, enforce: true)
                    
                    // Also add to subtitle manager for custom overlay option
                    let track = SubtitleTrack(name: srtUrl.lastPathComponent, url: srtUrl)
                    if !subtitleManager.availableTracks.contains(where: { $0.url == srtUrl }) {
                        subtitleManager.availableTracks.append(track)
                    }
                }
            }
        } catch {
            print("Subtitle discovery error: \(error)")
        }
    }
    
    private func setupVLCTimeObserver() {
        // Create a timer to ensure time updates and subtitles stay in sync for VLC
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, self.isVLC else { return }
                self.updateTimeFromVLC()
            }
        }
    }
    
    private func generateThumbnail(for video: VideoItem) {
        if let asset = video.asset {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 600, height: 600), contentMode: .aspectFill, options: options) { [weak self] image, _ in
                Task { @MainActor in
                    self?.videoThumbnail = image
                    self?.updateNowPlayingInfo()
                }
            }
        } else if let url = video.url {
            let asset = AVAsset(url: url)
            // configurePlayer(asset: asset) // REMOVED: Redundant and causes double initialization/flicker
            
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let time = CMTime(seconds: 1, preferredTimescale: 60)
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: time)]) { [weak self] _, image, _, _, _ in
                if let image = image {
                    let uiImage = UIImage(cgImage: image)
                    Task { @MainActor in
                        guard let self = self else { return }
                        self.videoThumbnail = uiImage
                        self.updateNowPlayingInfo()
                    }
                }
            }
        }
    }
    
    private func setupLifecycleObservers() {
        guard !isLifecycleSetup else { return }
        isLifecycleSetup = true
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    @objc private func appDidEnterBackground() {
        // We want audio to continue, so we don't pause here.
        // The .playback category handles this.
        print("App entered background - continuing audio")
        handleSleepTimerBackground()
    }
    
    @objc private func appWillEnterForeground() {
        print("App entering foreground")
        // Ensure PiP is marked inactive when app returns to foreground
        if isPiPActive { isPiPActive = false }
        
        handleSleepTimerForeground()
    }
    
    private func handleSleepTimerBackground() {
        if case .duration(_) = sleepTimerMode {
            sleepTimer?.invalidate()
            sleepTimer = nil
        }
    }
    
    private func handleSleepTimerForeground() {
        if case .duration(let remaining) = sleepTimerMode {
             startSleepTimer(duration: remaining)
        }
    }
    
    func handleRestoreFromPiP() {
        print("Restored from PiP - pausing and showing controls")
        self.isPiPActive = false
        self.pause()
        self.isControlsVisible = true
    }
    
    // ... configurePlayer ...
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in self.play() }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
             guard let self = self else { return .commandFailed }
             Task { @MainActor in self.pause() }
             return .success
        }
        
        commandCenter.skipForwardCommand.preferredIntervals = [10]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
             guard let self = self else { return .commandFailed }
             Task { @MainActor in self.seek(to: self.currentTime + 10) }
             return .success
        }
        
        commandCenter.skipBackwardCommand.preferredIntervals = [10]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
             guard let self = self else { return .commandFailed }
             Task { @MainActor in self.seek(to: self.currentTime - 10) }
             return .success
        }
        
        // Update Now Playing Info
        updateNowPlayingInfo()
    }
    
    @MainActor
    func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = videoTitle
        
        if let thumb = videoThumbnail {
             let artwork = MPMediaItemArtwork(boundsSize: thumb.size) { size in
                 return thumb
             }
             nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    

    
    
    @MainActor
    func togglePiP() {
        if isVLC {
            showPiPError = true
            return
        }
    
        if !isPiPActive {
            // Ensure video is playing when starting PiP for best transition
            if !isPlaying {
                play()
            }
            isPiPActive = true
            
            // For manual toggle: automatically background the app to trigger PiP immediately
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // Small delay for system to prep
                await MainActor.run {
                    if self.isPiPActive {
                        UIControl().sendAction(#selector(URLSessionTask.suspend), to: UIApplication.shared, for: nil)
                    }
                }
            }
        } else {
            isPiPActive = false
        }
    }
    

    
    // ...
    



    
    @MainActor
    private func configurePlayer(asset: AVAsset, autoPlay: Bool = true) {
        self.isVLC = false // Explicitly set to false when using AVPlayer
        let playerItem = AVPlayerItem(asset: asset)
        self.player = AVPlayer(playerItem: playerItem)
        
        // MARK: - External Playback Configuration
        // Enable AirPlay and external display routing
        self.player?.allowsExternalPlayback = true
        self.player?.usesExternalPlaybackWhileExternalScreenIsActive = true
        
        // Critical: Allow audio to continue in background even if video layer is hidden (non-PiP)
        if #available(iOS 15.0, *) {
            self.player?.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        }
        
        // Observe external playback state
        externalPlaybackObserver = self.player?.observe(\.isExternalPlaybackActive, options: [.new]) { [weak self] player, change in
            guard let self = self else { return }
            Task { @MainActor in
                self.isExternalPlaybackActive = player.isExternalPlaybackActive
            }
        }
        
        // Observe Player TimeControlStatus (Single Source of Truth for isPlaying)
        // This is more reliable than rate, especially for AirPlay and Buffering
        timeControlStatusObserver = self.player?.observe(\.timeControlStatus, options: [.new]) { [weak self] player, change in
            guard let self = self else { return }
            Task { @MainActor in
                self.isPlaying = (player.timeControlStatus == .playing || player.timeControlStatus == .waitingToPlayAtSpecifiedRate)
                self.updateNowPlayingInfo()
            }
        }
        
        // Fetch duration asynchronously
        Task {
            let duration = try? await asset.load(.duration)
            await MainActor.run {
                if let d = duration {
                    self.duration = CMTimeGetSeconds(d)
                    self.totalDurationString = self.formatTime(seconds: self.duration)
                    self.updateNowPlayingInfo()
                }
            }
        }
        
        // Resume Logic
        if let vid = videoId, let savedTime = UserDefaults.standard.value(forKey: "resume_\(vid)") as? Double {
            if savedTime > 0 && savedTime < (self.duration - 5) {
                // Seek to saved time
                self.seek(to: savedTime)
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if case .endOfTrack = self.sleepTimerMode {
                    self.cancelSleepTimer()
                    self.isPlaying = false
                    self.player?.pause()
                    self.shouldDismissPlayer = true // Dismiss player
                } else {
                    switch self.playingMode {
                    case .repeatOne:
                        self.seek(to: 0)
                        self.play()
                        
                    case .oneTrack:
                        self.isPlaying = false
                        self.player?.pause()
                        self.isControlsVisible = true
                        if let vid = self.videoId { UserDefaults.standard.removeObject(forKey: "resume_\(vid)") }
                        
                    case .playInOrder:
                        if self.currentIndex + 1 < self.playlist.count {
                             self.playNext(forceAutoPlay: true)
                        } else {
                             self.isPlaying = false
                             self.player?.pause()
                             self.isControlsVisible = true
                             if let vid = self.videoId { UserDefaults.standard.removeObject(forKey: "resume_\(vid)") }
                        }
                        
                    case .shufflePlay:
                         self.playNext(forceAutoPlay: true)
                    }
                }
            }
        }
        
        // Load embedded subtitle and audio tracks
        loadEmbeddedTracks(from: playerItem)
        
        if autoPlay {
            self.play()
        }
        addTimeObserver()
    }
    
    // MARK: - Embedded Track Support
    
    func loadEmbeddedTracks(from playerItem: AVPlayerItem) {
        // Load embedded tracks - REFACTORED to be fully async and non-blocking
        Task {
            let subtitleGroup = try? await playerItem.asset.loadMediaSelectionGroup(for: .legible)
            
            await MainActor.run {
                if let subtitleGroup = subtitleGroup {
                    let embeddedOptions = subtitleGroup.options
                    for option in embeddedOptions {
                        let trackName = option.displayName
                        let track = SubtitleTrack(name: "[Embedded] \(trackName)", url: nil)
                        
                        if !self.subtitleManager.availableTracks.contains(where: { $0.name == track.name }) {
                            self.subtitleManager.availableTracks.append(track)
                            self.embeddedSubtitleOptions.append(option)
                        }
                    }
                }
            }
        }
        
        // Load embedded audio tracks
        Task {
            let audioGroup = try? await playerItem.asset.loadMediaSelectionGroup(for: .audible)
            
            await MainActor.run {
                self.availableAudioTracks.removeAll()
                self.embeddedAudioOptions.removeAll()
                
                if let audioGroup = audioGroup {
                    let audioOptions = audioGroup.options
                    
                    if audioOptions.isEmpty {
                        // Has audioGroup but no options - check if asset has audio
                        Task {
                            let tracks = try? await playerItem.asset.load(.tracks)
                            var hasAudio = false
                            if let tracks = tracks {
                                for track in tracks {
                                    if track.mediaType == AVMediaType.audio {
                                        hasAudio = true
                                        break
                                    }
                                }
                            }
                            await MainActor.run {
                                if hasAudio {
                                    self.availableAudioTracks.append("Track 1")
                                    self.selectedAudioTrackIndex = 0
                                } else {
                                    self.selectedAudioTrackIndex = -1
                                }
                            }
                        }
                    } else if audioOptions.count == 1 && audioOptions[0].displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        // Scenario 2: Single unnamed track (phone video) - create "Track 1"
                        self.availableAudioTracks.append("Track 1")
                        self.embeddedAudioOptions.append(audioOptions[0])
                        self.selectedAudioTrackIndex = 0
                    } else {
                        // Scenario 1: Named tracks (MKV) - use original names
                        for option in audioOptions {
                            let trackName = option.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                            self.availableAudioTracks.append(trackName.isEmpty ? "Track \\(self.availableAudioTracks.count + 1)" : trackName)
                            self.embeddedAudioOptions.append(option)
                        }
                        self.selectedAudioTrackIndex = 0
                    }
                } else {
                    // No audioGroup - check if asset has audio tracks directly
                    Task {
                        let tracks = try? await playerItem.asset.load(.tracks)
                        var hasAudio = false
                        if let tracks = tracks {
                            for track in tracks {
                                if track.mediaType == AVMediaType.audio {
                                    hasAudio = true
                                    break
                                }
                            }
                        }
                        await MainActor.run {
                            if hasAudio {
                                self.availableAudioTracks.append("Track 1")
                                self.selectedAudioTrackIndex = 0
                            } else {
                                self.selectedAudioTrackIndex = -1
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    
    func selectEmbeddedSubtitle(at index: Int) {
        guard let playerItem = player?.currentItem else { return }
        
        Task {
            let subtitleGroup = try? await playerItem.asset.loadMediaSelectionGroup(for: .legible)
            guard let finalGroup = subtitleGroup, index >= 0 && index < embeddedSubtitleOptions.count else { return }
            
            let option = embeddedSubtitleOptions[index]
            playerItem.select(option, in: finalGroup)
        }
    }
    
    @MainActor
    private func handleSubtitleSelection(_ index: Int) {
        if isVLC {
            guard let videoPlayer = vlcPlayer else { return }
            
            if index == -1 {
                // Disable everything
                videoPlayer.currentVideoSubTitleIndex = -1 
                subtitleManager.isEnabled = false
                subtitleManager.currentSubtitle = ""
                return
            }
            
            if index >= 0 && index < subtitleManager.availableTracks.count {
                let track = subtitleManager.availableTracks[index]
                if let url = track.url {
                    // EXTERNAL track: Use Native VLC Engine
                    
                    // AVOID DUPLICATES: If VLC already has a track with this name, just select it
                    if let vlcID = vlcSubtitleMapping[track.name] {
                        videoPlayer.currentVideoSubTitleIndex = vlcID
                    } else {
                        // Fix: Copy to temp file to ensure VLC (C-Lib) can access it due to Sandbox
                        if let tempURL = createTempSubtitleFile(from: url) {
                             videoPlayer.addPlaybackSlave(tempURL, type: .subtitle, enforce: true)
                        } else {
                            // Fallback to original URL if copy fails
                             videoPlayer.addPlaybackSlave(url, type: .subtitle, enforce: true)
                        }
                    }
                } else {
                    // EMBEDDED track: Enable VLC native
                    if let vlcID = vlcSubtitleMapping[track.name] {
                        videoPlayer.currentVideoSubTitleIndex = vlcID
                    }
                }
            }
            return
        }


        
        // Debounce or ensure we have a player item
        guard let playerItem = player?.currentItem else {
            // If player not ready, we can't select. 
            // However, observer runs on init. 
            // We should ensure this runs also when player becomes available?
            // Actually setupPlayer clears subtitleManager, causing index -> -1.
            return 
        }
        
        Task {
            let group = try? await playerItem.asset.loadMediaSelectionGroup(for: .legible)
            guard let legibleGroup = group else { return }
            
            if index == -1 {
                // Disable native subtitles
                playerItem.select(nil, in: legibleGroup)
                return
            }
            
            // Get selected track from manager
            guard index >= 0 && index < subtitleManager.availableTracks.count else { return }
            let track = subtitleManager.availableTracks[index]
            
            if track.url == nil {
                // Embedded track
                // Find matching option based on naming convention
                if let option = self.embeddedSubtitleOptions.first(where: { 
                    "[Embedded] \($0.displayName)" == track.name 
                }) {
                     playerItem.select(option, in: legibleGroup)
                }
            } else {
                // External track: Disable native to avoid overlap
                playerItem.select(nil, in: legibleGroup)
            }
        }
    }
    
    @MainActor
    func selectSubtitleTrack(at index: Int) {
        if isVLC {
            let tracks = subtitleManager.availableTracks
            
            if index == -1 {
                subtitleManager.selectTrack(at: -1)
                return
            }
            
            guard index >= 0 && index < tracks.count else { return }
            
            // Just update the manager. 
            // The change observer (handleSubtitleSelection) will handle the VLC command.
            subtitleManager.selectTrack(at: index)
            return
        }
        
        // AVPlayer Logic
        guard let playerItem = player?.currentItem else { 
             subtitleManager.selectTrack(at: index)
             return 
        }
        
        if index == -1 {
            Task {
                if let legibleGroup = try? await playerItem.asset.loadMediaSelectionGroup(for: .legible) {
                    playerItem.select(nil, in: legibleGroup)
                }
                await MainActor.run {
                    subtitleManager.selectTrack(at: -1)
                }
            }
            return
        }
        
        let tracks = subtitleManager.availableTracks
        guard index >= 0 && index < tracks.count else { return }
        
        let track = tracks[index]
        if let _ = track.url {
            subtitleManager.selectTrack(at: index)
            Task {
                if let legibleGroup = try? await playerItem.asset.loadMediaSelectionGroup(for: .legible) {
                    playerItem.select(nil, in: legibleGroup)
                }
            }
        } else {
            let externalCount = tracks.filter { $0.url != nil }.count
            let embeddedIndex = index - externalCount
            
            if embeddedIndex >= 0 && embeddedIndex < embeddedSubtitleOptions.count {
                let option = embeddedSubtitleOptions[embeddedIndex]
                Task {
                    if let legibleGroup = try? await playerItem.asset.loadMediaSelectionGroup(for: .legible) {
                        playerItem.select(option, in: legibleGroup)
                    }
                    await MainActor.run {
                        subtitleManager.selectTrack(at: index)
                    }
                }
            }
        }
    }
    
    @MainActor
    func selectAudioTrack(at index: Int) {
        if isVLC {
            guard let videoPlayer = vlcPlayer else { return }
            
            if index == -1 {
                videoPlayer.audio?.isMuted = true
                self.selectedAudioTrackIndex = -1
            } else if index >= 0 && index < availableAudioTracks.count {
                let trackName = availableAudioTracks[index]
                if let vlcID = vlcAudioMapping[trackName] {
                    videoPlayer.audio?.isMuted = false
                    videoPlayer.currentAudioTrackIndex = vlcID
                    self.selectedAudioTrackIndex = index
                }
            }
            return
        }
        
        guard let playerItem = player?.currentItem else { return }
        
        if index == -1 {
            // Disable / Mute
            player?.isMuted = true
            self.selectedAudioTrackIndex = -1
            return
        }
        
        // Check if we have audio tracks but no embedded options (phone video with unnamed audio)
        if index >= 0 && index < availableAudioTracks.count && embeddedAudioOptions.isEmpty {
            // Phone video - just unmute
            player?.isMuted = false
            self.selectedAudioTrackIndex = index
            return
        }
        
        Task {
            let audioGroup = try? await playerItem.asset.loadMediaSelectionGroup(for: .audible)
            guard let finalGroup = audioGroup, index >= 0 && index < embeddedAudioOptions.count else { 
                // Fallback: just unmute if we have tracks but no options
                if index >= 0 && index < availableAudioTracks.count {
                    await MainActor.run {
                        player?.isMuted = false
                        self.selectedAudioTrackIndex = index
                    }
                }
                return 
            }
            
            let option = embeddedAudioOptions[index]
            playerItem.select(option, in: finalGroup)
            await MainActor.run {
                player?.isMuted = false
                self.selectedAudioTrackIndex = index
            }
        }
    }
    
    @MainActor
    func togglePlayPause() {
        if isVLC {
            if isPlaying {
                vlcPlayer?.pause()
                isPlaying = false
            } else {
                // Check if playback ended, if so, restart from beginning
                let vlcState = vlcPlayer?.state
                let isVlcEnded = vlcState == .ended || vlcState == .stopped
                
                // Check if we're at the end - multiple ways to detect:
                // 1. VLC position is near end
                // 2. Local currentTime is near end
                // 3. VLC is in .ended state (most reliable)
                let vlcPosition = vlcPlayer?.position ?? 0
                let safeDuration = max(duration, 0.1)
                let timeRatio = currentTime / safeDuration
                
                // Lower threshold to 0.95 (95%) and also check VLC position
                let isAtEnd = vlcPosition >= 0.99 || timeRatio >= 0.99
                
                // If VLC is ended OR we're at the end position, restart from 00:00
                if isVlcEnded || (isAtEnd && vlcPlayer?.isPlaying == false) {
                    // User tapped play when video is at the end - restart from 00:00
                    isPlaying = true // Set intent to play
                    currentTime = 0
                    currentTimeString = formatTime(seconds: 0)
                    seek(to: 0) // This will handle the VLC reset and start playing
                } else {
                    self.play()
                }
            }
            return
        }
        
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            // Check for end of playback to restart
            if let item = player.currentItem {
                if item.currentTime() >= item.duration {
                    player.seek(to: .zero)
                }
            }
            self.play()
        }
        // isPlaying state is handled by rate observer
    }
    
    @MainActor
    func play() {
        if isVLC {
             lastIntendedSeekPosition = nil // Clear on play
             vlcPlayer?.rate = playbackSpeed
             
             // Removed redundant currentAudioPlaybackDelay setting here to prevent audio dropout on resume.
             // The delay is already managed by the reactive observer and remembered by the VLC player instance.
             
             vlcPlayer?.play()
             isPlaying = true
             return
        }
        player?.playImmediately(atRate: playbackSpeed)
        isPlaying = true
    }
    
    @MainActor
    func pause() {
        if isVLC {
             vlcPlayer?.pause()
             isPlaying = false
             return
        }
        player?.pause()
        // isPlaying state is handled by rate observer
    }
    
    
    @MainActor
    func seek(to time: Double) {
        // Update local state immediately to prevent slider jump back
        self.currentTime = time
        self.currentTimeString = self.formatTime(seconds: time)
        self.subtitleManager.update(currentTime: time, audioDelay: self.audioDelay)
        
        if isVLC {
            isSeeking = true
            lastIntendedSeekPosition = time 
            
            // Identify if we need to wake up the player (Ended or Stopped)
            let vlcState = vlcPlayer?.state
            let isVlcEnded = vlcState == .ended || vlcState == .stopped
            
            if isVlcEnded {
                // AGGRESSIVE WAKE UP SEQUENCE FOR ENDED STATE
                // VLC in .ended state is essentially dead and needs a full reset
                
                seekRequestID += 1
                let currentID = seekRequestID
                
                // 1. Stop the player completely to reset its internal state
                vlcPlayer?.stop()
                
                // 2. Re-set the media (same media, but forces VLC to re-initialize)
                if let currentMedia = vlcPlayer?.media {
                    vlcPlayer?.media = currentMedia
                }
                
                // 3. Set position BEFORE play (VLC accepts position on stopped player sometimes)
                if duration > 0 {
                    vlcPlayer?.position = Float(time / duration)
                }
                
                // 4. Mute to prevent audio blip
                let wasMuted = vlcPlayer?.audio?.isMuted ?? false
                vlcPlayer?.audio?.isMuted = true
                
                // 5. Start playing
                vlcPlayer?.play()
                
                Task {
                    // 6. Wait for player to become active
                    var attempts = 0
                    while attempts < 15 { // 1.5 seconds max
                        let state = await MainActor.run { self.vlcPlayer?.state }
                        if state == .playing || state == .buffering {
                            break
                        }
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                        attempts += 1
                    }
                    
                    await MainActor.run {
                        // 7. Apply seek time again (redundancy)
                        let vlcTime = VLCTime(int: Int32(time * 1000))
                        self.vlcPlayer?.time = vlcTime
                        
                        // Also set position as double-redundancy
                        if self.duration > 0 {
                            self.vlcPlayer?.position = Float(time / self.duration)
                        }
                    }
                    
                    // 8. Wait for frame to render
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    
                    await MainActor.run {
                        // 9. Restore mute
                        if !wasMuted {
                            self.vlcPlayer?.audio?.isMuted = false
                        }
                        
                        // 10. Enforce user intent (pause if user didn't want to play)
                        if !self.isPlaying {
                            self.vlcPlayer?.pause()
                        }
                        
                        if self.seekRequestID == currentID {
                            self.isSeeking = false
                        }
                    }
                }
            } else {
                // NORMAL SEEK SEQUENCE (Playing or Paused but active)
                
                let wasVlcPlaying = vlcPlayer?.isPlaying ?? false
                // Pause briefly to ensure frame update consistency (legacy logic)
                if wasVlcPlaying {
                    vlcPlayer?.pause()
                }
                
                let vlcTime = VLCTime(int: Int32(time * 1000))
                vlcPlayer?.time = vlcTime
                
                seekRequestID += 1
                let currentID = seekRequestID
                
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    await MainActor.run {
                        // Restore state based on intent
                        if self.isPlaying {
                            self.vlcPlayer?.play()
                        } else {
                             if self.vlcPlayer?.isPlaying == true {
                                 self.vlcPlayer?.pause()
                             }
                        }
                        
                        if self.seekRequestID == currentID {
                            self.isSeeking = false
                        }
                    }
                }
            }
            return
        }
        
        isSeeking = true
        seekRequestID += 1
        let currentID = seekRequestID
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        // Precise seek for final position
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.seekRequestID == currentID {
                    self.isSeeking = false
                }
            }
        }
    }
    
    // Optimized for live scrubbing
    @MainActor
    func smoothSeek(to time: Double) {
        // Update local state for UI responsiveness
        self.currentTime = time
        self.currentTimeString = self.formatTime(seconds: time)
        self.subtitleManager.update(currentTime: time, audioDelay: self.audioDelay)
        
        if isVLC {
            isSeeking = true
            lastIntendedSeekPosition = time 
            
            // Only set time for smoother scrubbing
            // Setting both position and time causes stutter
            vlcPlayer?.time = VLCTime(int: Int32(time * 1000))
            
            seekRequestID += 1
            let currentID = seekRequestID
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                await MainActor.run {
                    if self.seekRequestID == currentID {
                        self.isSeeking = false
                    }
                }
            }
            return
        }
    
        isSeeking = true
        seekRequestID += 1
        let currentID = seekRequestID
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        // Use positiveInfinity tolerance for smooth scrubbing (snaps to keyframes)
        // Zero tolerance is too slow for live dragging and causes the video to freeze
        player?.seek(to: cmTime, toleranceBefore: .positiveInfinity, toleranceAfter: .positiveInfinity) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.seekRequestID == currentID {
                    self.isSeeking = false
                }
            }
        }
    }

    func formatTime(seconds: Double) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        
        if h > 0 {
            return String(format: "%i:%02i:%02i", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
    
    @MainActor
    func setSpeed(_ speed: Float) {
        if isVLC {
            vlcPlayer?.rate = speed
        } else {
            player?.rate = speed
        }
        playbackSpeed = speed
        if !isPlaying { 
            if isVLC {
                vlcPlayer?.pause()
            } else {
                player?.pause()
            }
        } else {
            if !isVLC {
                player?.playImmediately(atRate: speed)
            }
        }
    }
    
    @MainActor
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600) // Much faster updates for subs
        let obs = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Skip updates while seeking for smoother performance
                guard !self.isSeeking else { return }
                
                self.currentTime = time.seconds
                self.currentTimeString = self.formatTime(seconds: self.currentTime)
                
                // Update Subtitles with current audio delay factor
                self.subtitleManager.update(currentTime: self.currentTime, audioDelay: self.audioDelay)
                
                // Auto-save position every 5 seconds or so (throttled)
                if Int(self.currentTime) % 5 == 0 {
                    self.saveProgress()
                }
            }
        }
        self.timeObserver = obs
    }
    
    @MainActor
    private func saveProgress() {
        if let vid = self.videoId {
            UserDefaults.standard.set(self.currentTime, forKey: "resume_\(vid)")
        }
    }
    
    // ...
    
    @MainActor
    func cleanup() {
        saveProgress()
        
        // UI Cleanup tasks must be on main thread
        if let o = timeObserver {
            player?.removeTimeObserver(o)
            timeObserver = nil
        }
        
        subtitleManager.clear()
        
        // Clean up audio engine for AVPlayer audio delay
        cleanupAudioEngine()
        
        // Clear VLC track arrays
        vlcSubtitleMapping.removeAll()
        vlcAudioMapping.removeAll()
        availableAudioTracks.removeAll()
        availableSubtitles.removeAll()
        embeddedSubtitleOptions.removeAll()
        embeddedAudioOptions.removeAll()
        
        // Remove Remote Targets
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        
        vlcPlayer?.stop()
        vlcPlayer = nil
        player = nil
    }
    
    deinit {
        print("PlayerViewModel Deallocated")
        
        // nonisolated cleanup only
        externalPlaybackObserver?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    @MainActor
    func restoreBrightness() {
        if let initial = initialBrightness {
            UIScreen.main.brightness = initial
        }
    }
    
    @MainActor
    func toggleOrientation() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        let isLandscape = windowScene.interfaceOrientation.isLandscape
        
        // Update AppDelegate lock temporarily to allow transition
        AppDelegate.orientationLock = .all
        
        if #available(iOS 16.0, *) {
            let orientation: UIInterfaceOrientationMask = isLandscape ? .portrait : .landscapeRight
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation)) { error in
                print("Rotation failed: \(error.localizedDescription)")
            }
        } else {
            let targetValue = isLandscape ? UIInterfaceOrientation.portrait.rawValue : UIInterfaceOrientation.landscapeRight.rawValue
            UIDevice.current.setValue(targetValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}

// MARK: - VLC Delegates
extension PlayerViewModel: VLCMediaPlayerDelegate, VLCMediaDelegate {
    
    // MARK: - VLCMediaDelegate
    @objc func mediaDidFinishParsing(_ aMedia: VLCMedia) {
        Task { @MainActor in
            populateVLCTracksIfNeeded()
        }
    }
    
    // MARK: - VLCMediaPlayerDelegate
    @objc func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor in
            guard let notifyingPlayer = aNotification.object as? VLCMediaPlayer,
                  let currentPlayer = vlcPlayer,
                  notifyingPlayer == currentPlayer else { return }
            
            // Ignore state changes during seeking to prevent UI glitches
            guard !isSeeking else { return }
            
            switch currentPlayer.state {
            case .playing, .opening, .buffering:
                self.isPlaying = true
                if currentPlayer.state == .playing {
                    updateTimeFromVLC()
                    populateVLCTracksIfNeeded()
                }
            case .paused:
                self.isPlaying = false
            case .stopped, .ended:
                // When video ends, set currentTime to full duration so seek bar shows complete
                if currentPlayer.state == .ended {
                    // Force UI current time = total duration as requested for state-based completion
                    self.currentTime = self.duration
                    self.currentTimeString = self.formatTime(seconds: self.duration)
                    self.isPlaying = false
                }
                
                // Check Sleep Timer End of Track
                // Refinement: Only trigger on .ended (natural finish) to avoid killing player on manual change?
                // Or check if it was explicitly stopped by user?
                // VLC sends .stopped often.
                // If .endOfTrack is active, we should only stop if it truly ended.
                // But VLC .ended is what we want.
                if currentPlayer.state == .ended, case .endOfTrack = self.sleepTimerMode {
                    self.cancelSleepTimer() // Turn off timer as we reached end
                    self.isPlaying = false
                    self.player?.pause()
                    self.shouldDismissPlayer = true // Dismiss player
                } else if self.autoPlayNext && self.currentIndex + 1 < self.playlist.count {
                    self.playNext(forceAutoPlay: true)
                } else {
                    self.isPlaying = false
                    self.isControlsVisible = true // Show controls at the end
                    // self.didFinishPlayback = true // REMOVED: Stay in player
                }
            default:
                break
            }
        }
    }
    
    @objc func mediaPlayerTitleChanged(_ aNotification: Notification) {
        Task { @MainActor in
            populateVLCTracksIfNeeded()
        }
    }
    
    @objc func mediaPlayerLengthChanged(_ aNotification: Notification) {
        Task { @MainActor in
            populateVLCTracksIfNeeded()
        }
    }
    
    @objc func mediaPlayerTimeChanged(_ aNotification: Notification) {
        Task { @MainActor in
            updateTimeFromVLC()
        }
    }
    
    @MainActor
    private func updateTimeFromVLC() {
        guard let player = vlcPlayer, !isSeeking else { return }
        
        // If the video has ended, don't update time from player to avoid 
        // VLC's imprecise end-time reporting (e.g., 00:04 / 00:05)
        if player.state == .ended {
            self.currentTime = self.duration
            self.currentTimeString = formatTime(seconds: self.duration)
            return
        }
        
        var vlcTime = Double(player.time.intValue) / 1000.0
        
        // Clamp time to ensure it never exceeds duration or goes below zero
        vlcTime = min(max(0, vlcTime), duration)
        
        // If paused and we have a recent manual seek position, prevent overwrite
        if !isPlaying, let intendedPosition = lastIntendedSeekPosition {
            let difference = abs(vlcTime - intendedPosition)
            
            // If VLC's time doesn't match our intended position (within 1s tolerance), ignore it
            // VLC often reports old time while paused after a seek
            if difference > 1.0 {
                return 
            } else {
                // VLC has finally caught up/synced, we can clear the tracker
                lastIntendedSeekPosition = nil
            }
        }
        
        self.currentTime = vlcTime
        self.currentTimeString = formatTime(seconds: currentTime)
        
        // Update subtitles (For both AVPlayer and VLC external subtitles)
        self.subtitleManager.update(currentTime: self.currentTime, audioDelay: self.audioDelay)
        
        if let media = player.media {
            let length = media.length
            self.duration = Double(length.intValue) / 1000.0
            self.totalDurationString = formatTime(seconds: duration)
        }
        
        self.updateNowPlayingInfo()
    }
    
    private func takeVLCSnapshot(for bookmarkID: UUID) {
        guard isVLC, let player = vlcPlayer else { return }
        
        // Use caches directory to avoid backup bloat
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let bookmarksDir = cachesDir.appendingPathComponent("bookmarks")
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: bookmarksDir.path) {
            try? FileManager.default.createDirectory(at: bookmarksDir, withIntermediateDirectories: true)
        }
        
        let snapshotPath = bookmarksDir.appendingPathComponent("\(bookmarkID.uuidString).jpg").path
        // VLC's snapshot generator is efficient for low-res thumbs
        player.saveVideoSnapshot(at: snapshotPath, withWidth: 320, andHeight: 180)
    }
    
    // Unified formatting used by both AVPlayer and VLC updates

    // MARK: - Toggle Aspect Ratio
    @MainActor
    func toggleAspectRatio() {
        // Cycle next
        aspectRatio = aspectRatio.next
        updateAspectRatio(with: nil) 
    }
    
    @MainActor
    func updateAspectRatio(to newRatio: VideoAspectRatio) {
        aspectRatio = newRatio
        updateAspectRatio(with: nil)
    }

    @MainActor
    func updateAspectRatio(with size: CGSize? = nil) {
        if let size = size {
            lastKnownViewSize = size
        }
        
        if isVLC {
            updateVLCAspectRatio(with: lastKnownViewSize)
        }
    }

    @MainActor
    private func updateVLCAspectRatio(with size: CGSize? = nil) {
        guard let player = vlcPlayer else { return }
        
        // Use provided size, stored size, or fallback to main screen
        let targetSize = size ?? lastKnownViewSize ?? UIScreen.main.bounds.size
        
        // Helper to safely set aspect ratio using strdup to avoid Swift bridging release issues
        func setAR(_ ratio: String?) {
            if let r = ratio {
                let p = strdup(r)
                player.videoAspectRatio = p
                free(p)
            } else {
                player.videoAspectRatio = nil
            }
        }

        func setCrop(_ crop: String?) {
             if let c = crop {
                let p = strdup(c)
                player.videoCropGeometry = p
                free(p)
             } else {
                player.videoCropGeometry = nil
             }
        }
        
        // Reset crop by default to avoid stickiness
        setCrop(nil)
        
        switch aspectRatio {
        case .fit:
            setAR(nil)
            player.scaleFactor = 0
            
        case .fill:
            // "Fill" means Zoom to Fill.
            // We achieve this in VLC by cropping the video to the SCREEN/VIEW's aspect ratio.
            let ratioString = String(format: "%d:%d", Int(targetSize.width), Int(targetSize.height))
            
            setAR(nil) // Allow natural scaling of the crop
            setCrop(ratioString) // Crop video to view shape
            player.scaleFactor = 0
            
        case .stretch:
            let ratioString = String(format: "%d:%d", Int(targetSize.width), Int(targetSize.height))
            setAR(ratioString)
            player.scaleFactor = 0
            
        case .original:
            // "Original" means respecting source aspect ratio (Fit behavior).
            // Using logic similar to 'Fit' but with explicit reset.
            setAR(nil) 
            setCrop(nil)
            player.scaleFactor = 0 // Auto-scale to fit view (not native 1:1)
            
        case .sixteenByNine:
            setAR("16:9")
            player.scaleFactor = 0
            
        case .fourByThree:
            setAR("4:3")
            player.scaleFactor = 0
            
        case .sixteenByTen:
            setAR("16:10")
            player.scaleFactor = 0
            
        }
    }
    
    @MainActor
    private func populateVLCTracksIfNeeded() {
        guard let player = vlcPlayer else { return }
        
        // Preserve external tracks (those with URLs)
        let externalTracks = subtitleManager.availableTracks.filter { $0.url != nil }
        
        // 1. Subtitles
        self.vlcSubtitleMapping.removeAll()
        var newTracks: [SubtitleTrack] = []
        
        // VLC bridges these as NSArray of NSNumber
        let vlcSubNames = player.videoSubTitlesNames as? [String] ?? []
        let vlcSubIndexes = (player.videoSubTitlesIndexes as? [NSNumber])?.map { $0.int32Value } ?? []
        
        // Use a set to track which external tracks we've matched to VLC
        var matchedExternalIndices = Set<Int>()
        
        for (index, vlcName) in zip(vlcSubIndexes, vlcSubNames) {
            if index == -1 { continue }
            
            let cleanName = vlcName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Try to match this VLC track to an already known external track
            var foundMatch = false
            for (extIdx, extTrack) in externalTracks.enumerated() {
                if matchedExternalIndices.contains(extIdx) { continue }
                
                // Match by exact name or if VLC gives it a generic name and it's our only external track
                if extTrack.name == cleanName || (cleanName.hasPrefix("Track") && externalTracks.count == 1) {
                    let combinedTrack = SubtitleTrack(name: extTrack.name, url: extTrack.url)
                    newTracks.append(combinedTrack)
                    self.vlcSubtitleMapping[extTrack.name] = index
                    self.vlcSubtitleMapping[cleanName] = index
                    matchedExternalIndices.insert(extIdx)
                    foundMatch = true
                    break
                }
            }
            
            if !foundMatch {
                // Embedded or newly found VLC track
                let track = SubtitleTrack(name: cleanName, url: nil)
                newTracks.append(track)
                self.vlcSubtitleMapping[cleanName] = index
            }
        }
        
        // Add any external tracks that VLC haven't reported yet (still relevant for selection)
        for (extIdx, extTrack) in externalTracks.enumerated() {
            if !matchedExternalIndices.contains(extIdx) {
                newTracks.append(extTrack)
            }
        }
        
        self.subtitleManager.availableTracks = newTracks
        self.availableSubtitles = newTracks.map { $0.name }
        
        // Map current VLC selection for subtitles
        let currentSubID = player.currentVideoSubTitleIndex
        if currentSubID == -1 {
            // VLC often reports -1 for external tracks it's currently rendering
            if subtitleManager.selectedTrackIndex >= 0 && subtitleManager.selectedTrackIndex < newTracks.count {
                let track = newTracks[subtitleManager.selectedTrackIndex]
                if track.url != nil {
                    // It's an external track, keep the current selection and ensure it's marked as enabled
                    subtitleManager.isEnabled = true
                } else {
                    subtitleManager.selectedTrackIndex = -1
                    subtitleManager.isEnabled = false
                }
            } else {
                subtitleManager.selectedTrackIndex = -1
                subtitleManager.isEnabled = false
            }
        } else {
            // Find which track name corresponds to this currentSubID
            if let matchedName = vlcSubtitleMapping.first(where: { $0.value == currentSubID })?.key {
                 // Now find where this name is in our newTracks list
                if let unifiedIndex = newTracks.firstIndex(where: { $0.name == matchedName }) {
                    subtitleManager.selectedTrackIndex = unifiedIndex
                    subtitleManager.isEnabled = true
                }
            }
        }
        
        // 2. Audio
        self.availableAudioTracks.removeAll()
        self.vlcAudioMapping.removeAll()
        
        let vlcAudioNames = player.audioTrackNames as? [String] ?? []
        let vlcAudioIndexesArr = (player.audioTrackIndexes as? [NSNumber])?.map { $0.int32Value } ?? []
        
        // Filter out -1 (disable option)
        let validTracks = zip(vlcAudioIndexesArr, vlcAudioNames).filter { $0.0 != -1 }
        
        if validTracks.isEmpty {
            // Scenario 3: No audio tracks
            self.selectedAudioTrackIndex = -1
        } else if validTracks.count == 1 && validTracks.first!.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Scenario 2: Single unnamed track (phone video) - create "Track 1"
            self.availableAudioTracks.append("Track 1")
            self.vlcAudioMapping["Track 1"] = validTracks.first!.0
            self.selectedAudioTrackIndex = 0
        } else {
            // Scenario 1: Named tracks (MKV) - use original names
            for (index, name) in validTracks {
                let trackName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let finalName = trackName.isEmpty ? "Track \(self.availableAudioTracks.count + 1)" : trackName
                self.availableAudioTracks.append(finalName)
                self.vlcAudioMapping[finalName] = index
            }
            self.selectedAudioTrackIndex = 0
        }
        
        // Show selection state
        if player.audio?.isMuted ?? false {
            self.selectedAudioTrackIndex = -1
        } else {
            // Set current selection for audio
            let currentAudioID = player.currentAudioTrackIndex
            if let matchedName = vlcAudioMapping.first(where: { $0.value == currentAudioID })?.key,
               let audioIndex = availableAudioTracks.firstIndex(of: matchedName) {
                self.selectedAudioTrackIndex = audioIndex
            } else if !availableAudioTracks.isEmpty {
                self.selectedAudioTrackIndex = 0
            } else {
                self.selectedAudioTrackIndex = -1
            }
        }
        
        // RETRY MECHANISM: If tracks are still 0, retry in 0.5s (VLC sometimes takes time to parse tracks)
        if vlcSubtitleMapping.isEmpty && vlcAudioMapping.isEmpty {
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await MainActor.run { [weak self] in
                    self?.populateVLCTracksIfNeeded()
                }
            }
        }
    }
    
    
    // MARK: - Sleep Timer
    
    @MainActor
    func startSleepTimer(minutes: Int) {
        let duration = TimeInterval(minutes * 60)
        startSleepTimer(duration: duration)
        sleepTimerOriginalDuration = duration // Store original only when starting new
    }
    
    @MainActor
    func startSleepTimer(duration: TimeInterval) {
        cancelSleepTimer(keepMode: true) // invalidates timer but keeps mode if we are setting it
        
        sleepTimerMode = .duration(duration)
        updateSleepTimerString(remaining: duration)
        
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if case .duration(let remaining) = self.sleepTimerMode {
                    let newRemaining = remaining - 1
                    
                    if newRemaining <= 0 {
                        self.pause()
                        self.cancelSleepTimer()
                        self.shouldDismissPlayer = true
                    } else {
                        self.sleepTimerMode = .duration(newRemaining)
                        self.updateSleepTimerString(remaining: newRemaining)
                    }
                }
            }
        }
    }
    
    @MainActor
    func setSleepTimerEndOfTrack() {
        cancelSleepTimer()
        sleepTimerMode = .endOfTrack
        sleepTimerRemainingString = "End of track"
    }
    
    @MainActor
    func cancelSleepTimer(keepMode: Bool = false) {
        sleepTimer?.invalidate()
        sleepTimer = nil
        if !keepMode {
            sleepTimerMode = .off
            sleepTimerRemainingString = nil
            sleepTimerOriginalDuration = nil
        }
    }
    
    @MainActor
    private func updateSleepTimerString(remaining: TimeInterval) {
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        sleepTimerRemainingString = String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - AVPlayer Audio Delay
    
    private func applyAudioDelayToAVPlayer(_ delayInMs: Double, playerItem: AVPlayerItem) {
        currentAudioDelayMs = delayInMs
        
        // If delay is 0, remove audio processing
        if abs(delayInMs) < 0.1 {
            cleanupAudioEngine()
            return
        }
        
        // Setup audio engine with delay
        setupAudioEngineWithDelay(for: playerItem, delayMs: delayInMs)
    }
    
    private func setupAudioEngineWithDelay(for playerItem: AVPlayerItem, delayMs: Double) {
        // AVPlayerItemAudioOutput is not available in iOS SDK
        // Audio delay functionality only works with VLC player
        print("Audio delay is only supported for VLC player. AVPlayer does not support audio delay.")
        
        // Note: For AVPlayer, audio delay would require complex AVAudioEngine setup
        // with MTAudioProcessingTap which is beyond the scope of this implementation
    }
    
    private func processAudioWithDelay(output: Any?, playerNode: AVAudioPlayerNode, delayMs: Double, format: AVAudioFormat) {
        // This function is not implemented as AVPlayerItemAudioOutput is not available in iOS
        // Audio delay only works with VLC player
    }
    
    private func cleanupAudioEngine() {
        audioPlayerNode?.stop()
        audioEngine?.stop()
        
        // Note: audioOutput cleanup removed as AVPlayerItemAudioOutput is not available
        
        audioEngine = nil
        audioPlayerNode = nil
        // audioOutput = nil
        audioDelayBuffer.removeAll()
        
        // Restore player volume
        Task { @MainActor in
            self.player?.volume = 1.0
        }
    }
    // Helper to bypass sandbox issues for VLC
    private func createTempSubtitleFile(from url: URL) -> URL? {
        do {
            // Provide security scope access if needed
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }
            
            let data = try Data(contentsOf: url)
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent("vlc_temp_sub_\(UUID().uuidString).srt")
            try data.write(to: tempFile)
            return tempFile
        } catch {
            print("Failed to create temp subtitle file: \(error)")
            return nil
        }
    }
}

