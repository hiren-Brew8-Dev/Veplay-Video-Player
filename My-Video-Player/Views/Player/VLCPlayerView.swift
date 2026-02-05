import SwiftUI
import MobileVLCKit
import AVKit

struct VLCPlayerView: UIViewRepresentable {
    var mediaPlayer: VLCMediaPlayer
    @Binding var isPiPActive: Bool

    func makeUIView(context: Context) -> VLCPlayerUIView {
        let view = VLCPlayerUIView(mediaPlayer: mediaPlayer)
        context.coordinator.setupPiP(with: view)
        return view
    }

    func updateUIView(_ uiView: VLCPlayerUIView, context: Context) {
        if isPiPActive {
            context.coordinator.startPiP()
        } else {
            context.coordinator.stopPiP()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        var parent: VLCPlayerView
        var pipController: AVPictureInPictureController?
        
        init(_ parent: VLCPlayerView) {
            self.parent = parent
        }
        
        func setupPiP(with view: VLCPlayerUIView) {
            guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
            
            // For VLC, we use a hidden AVPlayer to trigger the PiP window
            // because AVPictureInPictureController requires an AVPlayerLayer or AVSampleBufferDisplayLayer.
            // This is the most reliable workaround for non-native players.
            
            // We'll use the view's playerLayer (which is a dummy)
            pipController = AVPictureInPictureController(playerLayer: view.dummyPlayerLayer)
            pipController?.delegate = self
            pipController?.canStartPictureInPictureAutomaticallyFromInline = true
        }
        
        func startPiP() {
            pipController?.startPictureInPicture()
        }
        
        func stopPiP() {
            pipController?.stopPictureInPicture()
        }
        
        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            parent.isPiPActive = false
        }
    }
}

class VLCPlayerUIView: UIView {
    private var mediaPlayer: VLCMediaPlayer
    let dummyPlayerLayer = AVPlayerLayer()
    private let dummyPlayer = AVPlayer() // Silent/Empty player to satisfy PiP requirements
    
    init(mediaPlayer: VLCMediaPlayer) {
        self.mediaPlayer = mediaPlayer
        super.init(frame: .zero)
        self.backgroundColor = .black
        
        // CRITICAL: VLC drawable MUST be set synchronously on main thread
        // The async was causing VLC's internal OpenGL thread to modify layers off main thread
        assert(Thread.isMainThread, "VLCPlayerUIView must be initialized on main thread")
        mediaPlayer.drawable = self
        
        // Setup Dummy Player for PiP window
        dummyPlayerLayer.player = dummyPlayer
        dummyPlayerLayer.videoGravity = .resizeAspect
        dummyPlayerLayer.opacity = 0.01 // Nearly invisible
        layer.addSublayer(dummyPlayerLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        // Stop VLC from using this view before it's destroyed
        // This must also be synchronous to prevent race conditions
        if Thread.isMainThread {
            mediaPlayer.drawable = nil
        } else {
            DispatchQueue.main.sync {
                mediaPlayer.drawable = nil
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        dummyPlayerLayer.frame = self.bounds
    }
}
