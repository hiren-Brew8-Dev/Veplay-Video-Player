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
            if isVLC {
                updateVLCAspectRatio()
            }
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
    
    // Internal state
    private var timeObserver: Any?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var externalPlaybackObserver: NSKeyValueObservation?
    private var videoId: String?
    @MainActor var videoTitle: String = ""
    @MainActor @Published var videoThumbnail: UIImage?
    
    @MainActor @Published var currentTimeString: String = "00:00"
    @MainActor @Published var totalDurationString: String = "00:00"
    
    // Rotation & Brightness
    private var initialBrightness: CGFloat?
    @MainActor @Published var showBrightnessUI: Bool = false
    @MainActor @Published var currentBrightness: Float = Float(UIScreen.main.brightness)
    private var brightnessHideWorkItem: DispatchWorkItem?
    
    // PiP
    @MainActor @Published var isPiPActive: Bool = false
    @MainActor @Published var showPiPError: Bool = false
    @MainActor @Published var showAspectRatioToast: Bool = false
    private var toastTask: Task<Void, Never>?
    
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
    
    // Sharing & Snapshot
    // Sharing & Snapshot
    @MainActor @Published var currentVideoItem: VideoItem?
    @MainActor @Published var currentVideoURL: URL?
    @MainActor @Published var showSnapshotSavedToast: Bool = false
        
    // Skip/Seek Tracking
    @MainActor @Published var accumulatedSkipAmount: Double = 0
    private var lastSeekForward: Bool? = nil
    private var skipResetTask: Task<Void, Never>?
    private var seekAnchorTime: Double = 0
    
    // Subtitles Support
    let subtitleManager = SubtitleManager()
    private var embeddedSubtitleOptions: [AVMediaSelectionOption] = []
    private var embeddedAudioOptions: [AVMediaSelectionOption] = []
    private var vlcSubtitleIndexes: [Int32] = []
    private var vlcAudioIndexes: [Int32] = []
    
    // Audio Engine for AVPlayer audio delay
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var audioOutput: AVPlayerItemAudioOutput?
    private var audioDelayBuffer: [AVAudioPCMBuffer] = []
    private var currentAudioDelayMs: Double = 0
    
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
        case twoThirtyFiveByOne = "2.35:1"
        case oneEightyFiveByOne = "1.85:1"

        var gravity: AVLayerVideoGravity {
            switch self {
            case .fit, .original: return .resizeAspect
            case .fill: return .resizeAspectFill
            case .stretch, .sixteenByNine, .fourByThree, .sixteenByTen, .twoThirtyFiveByOne, .oneEightyFiveByOne: return .resize
            }
        }

        var ratioValue: CGFloat? {
            switch self {
            case .sixteenByNine: return 16.0 / 9.0
            case .fourByThree: return 4.0 / 3.0
            case .sixteenByTen: return 16.0 / 10.0
            case .twoThirtyFiveByOne: return 2.35 / 1.0
            case .oneEightyFiveByOne: return 1.85 / 1.0
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
            case .twoThirtyFiveByOne: return "2.35"
            case .oneEightyFiveByOne: return "1.85"
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
            default: return .fit // Reset to start for others
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
    }
    
    @MainActor @Published var playingMode: PlayingMode = .playInOrder

    @MainActor
    func performDoubleTapSeek(forward: Bool) {
        let baseSkip: Double = 10
        
        // Force controls hidden during skip
        isControlsVisible = false
        
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
            targetTime = max(0, min(targetTime, duration))
        } else {
            targetTime = max(0, targetTime)
        }
        
        // 5. Update display amount to what we actually skipped
        accumulatedSkipAmount = abs(targetTime - seekAnchorTime)
        
        // 6. Seek
        seek(to: targetTime)
        
        // 7. Reset the 1.5s hide timer
        showSeekUI(forward: forward)
    }

    @MainActor
    func showSeekUI(forward: Bool) {
        self.isSeekForward = forward
        self.isSeekUIActive = true
        
        skipResetTask?.cancel()
        skipResetTask = Task {
            // Updated to 1.5s as requested
            try? await Task.sleep(nanoseconds: 1_500_000_000) 
            
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
        self.subtitleManager.clear()
        
        // Clear VLC-specific track arrays for fresh state
        self.vlcSubtitleIndexes.removeAll()
        self.vlcAudioIndexes.removeAll()
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

        // Check for VLC Types
        if let url = video.url, isVLCFormat(url) {
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
    
    private func isVLCFormat(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let vlcExtensions = ["mkv", "avi", "wmv", "flv", "webm", "3gp", "vob", "mpg", "mpeg", "ts", "m2ts", "divx", "asf"]
        return vlcExtensions.contains(ext)
    }
    
    @MainActor
    private func setupVLCPlayer(url: URL, autoPlay: Bool = true) {
        self.isVLC = true
        self.vlcPlayer = VLCMediaPlayer()
        let media = VLCMedia(url: url)
        
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
            self.play()
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
        // Create a timer to update subtitles for VLC playback
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self = self, self.isVLC, let player = self.vlcPlayer, !self.isSeeking else { return }
                
                // Track current time
                self.currentTime = Double(player.time.intValue) / 1000.0
                self.currentTimeString = self.formatTime(seconds: self.currentTime)
                
                // Update subtitles
                self.subtitleManager.update(currentTime: self.currentTime)
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
            // VLC PiP is not currently supported in this implementation
            showPiPError = true
            return
        }
    
        if !isPiPActive {
            // Ensure video is playing when starting PiP for best transition
            if !isPlaying {
                play()
            }
            
            isPiPActive = true
            // Directly background the app to show the PiP player on Home screen
            // 0.4s delay gives the system enough time to initiate the PiP transition
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                await MainActor.run {
                    if self.isPiPActive { // Check if user didn't toggle back already
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
                    // EXTERNAL track: Disable VLC native, enable custom overlay
                    videoPlayer.currentVideoSubTitleIndex = -1
                    subtitleManager.loadSubtitle(from: url, trackName: track.name)
                    subtitleManager.isEnabled = true
                } else {
                    // EMBEDDED track: Enable VLC native, disable custom overlay text
                    // We need to find the correct VLC ID for this track
                    // Embedded tracks are appended after external ones in populateVLCTracksIfNeeded
                    let externalCount = subtitleManager.availableTracks.count - vlcSubtitleIndexes.count
                    let embeddedIndex = index - externalCount
                    if embeddedIndex >= 0 && embeddedIndex < vlcSubtitleIndexes.count {
                        let vlcID = vlcSubtitleIndexes[embeddedIndex]
                        videoPlayer.currentVideoSubTitleIndex = vlcID
                        subtitleManager.isEnabled = false // Disable overlay to avoid dual subs
                        subtitleManager.currentSubtitle = ""
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
    func selectAudioTrack(at index: Int) {
        if isVLC {
            guard let videoPlayer = vlcPlayer else { return }
            
            if index == -1 {
                // Disable / Mute
                videoPlayer.audio?.isMuted = true
                self.selectedAudioTrackIndex = -1
            } else if index >= 0 && index < vlcAudioIndexes.count {
                let vlcID = vlcAudioIndexes[index]
                videoPlayer.audio?.isMuted = false
                videoPlayer.currentAudioTrackIndex = vlcID
                self.selectedAudioTrackIndex = index
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
                // Check if playback ended, if so, restart
                if vlcPlayer?.state == .ended || (vlcPlayer?.state == .stopped && vlcPlayer?.position ?? 0 >= 0.99) {
                    vlcPlayer?.position = 0
                }
                self.play()
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
             vlcPlayer?.rate = playbackSpeed
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
        self.subtitleManager.update(currentTime: time)
        
        if isVLC {
            isSeeking = true
            let vlcTime = VLCTime(int: Int32(time * 1000))
            vlcPlayer?.time = vlcTime
            
            seekRequestID += 1
            let currentID = seekRequestID
            Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
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
        self.subtitleManager.update(currentTime: time)
        
        if isVLC {
            isSeeking = true
            let vlcTime = VLCTime(int: Int32(time * 1000))
            vlcPlayer?.time = vlcTime
            
            // Auto-reset isSeeking after a short delay if no more smooth seeks come in
            seekRequestID += 1
            let currentID = seekRequestID
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
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
        
        // Use small tolerance to force frame updates while dragging (even if paused),
        // but not zero tolerance which would be too slow.
        let tolerance = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        player?.seek(to: cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.seekRequestID == currentID {
                    self.isSeeking = false
                }
            }
        }
    }

    private func formatTime(seconds: Double) -> String {
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
                
                // Update Subtitles
                self.subtitleManager.update(currentTime: self.currentTime)
                
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
        vlcSubtitleIndexes.removeAll()
        vlcAudioIndexes.removeAll()
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
        self.currentTime = Double(player.time.intValue) / 1000.0
        self.currentTimeString = formatTime(seconds: currentTime)
        
        if let media = player.media {
            let length = media.length
            self.duration = Double(length.intValue) / 1000.0
            self.totalDurationString = formatTime(seconds: duration)
        }
        
        self.updateNowPlayingInfo()
    }
    
    // Unified formatting used by both AVPlayer and VLC updates

    // MARK: - Toggle Aspect Ratio
    @MainActor
    func toggleAspectRatio() {
        // Cycle next
        aspectRatio = aspectRatio.next
        updateAspectRatio(with: nil) 
        
        // Show Toast with ID-based transition handling
        toastTask?.cancel()
        
        // Ensure it's true (if it was false, it appears. If true, it just stays)
        // Note: Changing the text (aspectRatio.shortLabel) inside the view will update correctly.
        showAspectRatioToast = true
        
        toastTask = Task {
            // Updated to 0.5s as requested
            try? await Task.sleep(nanoseconds: 500_000_000) 
            if !Task.isCancelled {
                showAspectRatioToast = false
            }
        }
    }

    @MainActor
    func updateAspectRatio(with size: CGSize? = nil) {
        if isVLC {
            updateVLCAspectRatio(with: size)
        }
    }

    @MainActor
    private func updateVLCAspectRatio(with size: CGSize? = nil) {
        guard let player = vlcPlayer else { return }
        
        // Helper to safely set aspect ratio using strdup to avoid Swift bridging release issues
        // We rely on VLC copying the string. If VLC keeps the pointer, we would leak.
        // Standard VLC property behavior is copy.
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
            
            // Use provided size or fallback to main screen
            let targetSize = size ?? UIScreen.main.bounds.size
            let ratioString = String(format: "%d:%d", Int(targetSize.width), Int(targetSize.height))
            
            setAR(nil) // Allow natural scaling of the crop
            setCrop(ratioString) // Crop video to view shape
            player.scaleFactor = 0
            
        case .stretch:
            let targetSize = size ?? UIScreen.main.bounds.size
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
            
        case .twoThirtyFiveByOne:
            setAR("2.35:1")
            player.scaleFactor = 0
            
        case .oneEightyFiveByOne:
            setAR("1.85:1")
            player.scaleFactor = 0
        }
    }
    
    @MainActor
    private func populateVLCTracksIfNeeded() {
        guard let player = vlcPlayer else { return }
        
        // Preserve external tracks (those with URLs)
        let externalTracks = subtitleManager.availableTracks.filter { $0.url != nil }
        
        // 1. Subtitles
        self.vlcSubtitleIndexes.removeAll()
        var newTracks = externalTracks
        var subTitlesNames: [String] = []
        
        // VLC bridges these as NSArray of NSNumber
        let vlcSubNames = player.videoSubTitlesNames as? [String] ?? []
        let vlcSubIndexes = (player.videoSubTitlesIndexes as? [NSNumber])?.map { $0.int32Value } ?? []
        
        for (index, name) in zip(vlcSubIndexes, vlcSubNames) {
            if index == -1 { continue }
            
            // Check if this is an external track we already discovered (VLC includes playback slaves in this list)
            if externalTracks.contains(where: { $0.name == name }) {
                // If it's already in our external tracks, we'll store its index for selection mapping
                self.vlcSubtitleIndexes.append(index)
                continue
            }
            
            // Embedded or newly found VLC track
            let track = SubtitleTrack(name: name, url: nil)
            newTracks.append(track)
            subTitlesNames.append(name)
            self.vlcSubtitleIndexes.append(index)
        }
        
        self.subtitleManager.availableTracks = newTracks
        self.availableSubtitles = externalTracks.map { $0.name } + subTitlesNames
        
        // Map current VLC selection for subtitles
        let currentSubID = player.currentVideoSubTitleIndex
        if currentSubID == -1 {
            if subtitleManager.selectedTrackIndex >= 0 && subtitleManager.selectedTrackIndex < externalTracks.count {
                // Keep external selection
            } else {
                subtitleManager.selectedTrackIndex = -1
            }
        } else if let vlcIndex = vlcSubtitleIndexes.firstIndex(of: currentSubID) {
            // Check if this vlcID belongs to an external track
            let name = vlcSubNames[vlcSubIndexes.firstIndex(of: currentSubID) ?? 0]
            if let extIndex = externalTracks.firstIndex(where: { $0.name == name }) {
                subtitleManager.selectedTrackIndex = extIndex
            } else {
                subtitleManager.selectedTrackIndex = externalTracks.count + vlcIndex
            }
        }
        
        // 2. Audio
        self.availableAudioTracks.removeAll()
        self.vlcAudioIndexes.removeAll()
        
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
            self.vlcAudioIndexes.append(validTracks.first!.0)
            self.selectedAudioTrackIndex = 0
        } else {
            // Scenario 1: Named tracks (MKV) - use original names
            for (index, name) in validTracks {
                let trackName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                self.availableAudioTracks.append(trackName.isEmpty ? "Track \\(self.availableAudioTracks.count + 1)" : trackName)
                self.vlcAudioIndexes.append(index)
            }
            self.selectedAudioTrackIndex = 0
        }
        
        // Show selection state
        if player.audio?.isMuted ?? false {
            self.selectedAudioTrackIndex = -1
        } else {
            // Set current selection for audio
            let currentAudioID = player.currentAudioTrackIndex
            if let audioIndex = vlcAudioIndexes.firstIndex(of: currentAudioID) {
                self.selectedAudioTrackIndex = audioIndex
            } else if !availableAudioTracks.isEmpty {
                // If not muted but no match, maybe default to 0
                self.selectedAudioTrackIndex = 0
            } else {
                self.selectedAudioTrackIndex = -1
            }
        }
        
        // RETRY MECHANISM: If tracks are still 0, retry in 0.5s (VLC sometimes takes time to parse tracks)
        if vlcSubtitleIndexes.isEmpty && vlcAudioIndexes.isEmpty {
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
        // Clean up existing audio engine
        cleanupAudioEngine()
        
        // Mute the original player audio since we'll route through audio engine
        Task { @MainActor in
            self.player?.volume = 0
        }
        
        // Create audio output
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let output = AVPlayerItemAudioOutput(audioSettings: audioSettings)
        playerItem.add(output)
        self.audioOutput = output
        
        // Create and configure audio engine
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        
        engine.attach(playerNode)
        
        // Connect player node to output
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        
        self.audioEngine = engine
        self.audioPlayerNode = playerNode
        
        // Start the engine
        do {
            try engine.start()
            playerNode.play()
            
            // Start audio processing with delay
            processAudioWithDelay(output: output, playerNode: playerNode, delayMs: delayMs, format: format)
        } catch {
            print("Failed to start audio engine: \\(error)")
            cleanupAudioEngine()
        }
    }
    
    private func processAudioWithDelay(output: AVPlayerItemAudioOutput, playerNode: AVAudioPlayerNode, delayMs: Double, format: AVAudioFormat) {
        // Calculate delay in samples
        let delaySamples = Int((delayMs / 1000.0) * format.sampleRate)
        let bufferSize: AVAudioFrameCount = 4096
        
        // Create delay buffer
        var delayBufferFrames: [AVAudioPCMBuffer] = []
        
        // Process audio in background
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            
            var audioTimeStamp = CMTime.zero
            
            while self.audioEngine != nil && self.audioOutput != nil {
                // Get audio buffer from player
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize)!
                
                var itemTime = CMTime.zero
                if output.hasNewAudioSamples(forHostTime: audioTimeStamp) {
                    let frameCount = output.copyNextSampleBuffer()?.numSamples ?? 0
                    
                    if frameCount > 0 {
                        // Add to delay buffer
                        delayBufferFrames.append(buffer)
                        
                        // If we have enough delayed samples, play them
                        if delayBufferFrames.count * Int(bufferSize) >= delaySamples {
                            if let delayedBuffer = delayBufferFrames.first {
                                playerNode.scheduleBuffer(delayedBuffer)
                                delayBufferFrames.removeFirst()
                            }
                        }
                    }
                }
                
                // Small sleep to avoid busy loop
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
    }
    
    private func cleanupAudioEngine() {
        audioPlayerNode?.stop()
        audioEngine?.stop()
        
        if let output = audioOutput, let playerItem = player?.currentItem {
            playerItem.remove(output)
        }
        
        audioEngine = nil
        audioPlayerNode = nil
        audioOutput = nil
        audioDelayBuffer.removeAll()
        
        // Restore player volume
        Task { @MainActor in
            self.player?.volume = 1.0
        }
    }
}

