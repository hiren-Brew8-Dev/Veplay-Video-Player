import XCTest
@testable import Video_Player // Assuming module name, adjust if needed

class PlayerViewModelTests: XCTestCase {
    
    var viewModel: PlayerViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = PlayerViewModel()
        // Mock video item
        let mockVideo = VideoItem(title: "Test Video", duration: 100, creationDate: Date(), fileSizeBytes: 1024)
        viewModel.setupPlayer(with: mockVideo)
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertEqual(viewModel.currentTime, 0)
        XCTAssertEqual(viewModel.playbackSpeed, 1.0)
        XCTAssertFalse(viewModel.isPiPActive)
    }
    
    func testPlayPauseToggle() {
        // Initial: Paused
        XCTAssertFalse(viewModel.isPlaying)
        
        // Action: Play
        viewModel.play()
        XCTAssertTrue(viewModel.isPlaying)
        
        // Action: Pause
        viewModel.pause()
        XCTAssertFalse(viewModel.isPlaying)
        
        // Action: Toggle
        viewModel.togglePlayPause()
        XCTAssertTrue(viewModel.isPlaying)
    }
    
    func testSeeking() {
        let targetTime: Double = 50.0
        
        // Mock expectation since seeking is async block usually, but VM updates seeking state
        viewModel.seek(to: targetTime)
        
        XCTAssertTrue(viewModel.isSeeking)
        // In a real integration test we'd wait for limits, but here we test the intent logic
    }
    
    func testPlaybackSpeed() {
        viewModel.setSpeed(1.5)
        XCTAssertEqual(viewModel.playbackSpeed, 1.5)
        
        viewModel.setSpeed(2.0)
        XCTAssertEqual(viewModel.playbackSpeed, 2.0)
    }
    
    func testPiPToggle() {
        XCTAssertFalse(viewModel.isPiPActive)
        
        viewModel.togglePiP()
        XCTAssertTrue(viewModel.isPiPActive)
        
        viewModel.togglePiP()
        XCTAssertFalse(viewModel.isPiPActive)
    }
    
    func testAspectRatioCycling() {
        // Default
        XCTAssertEqual(viewModel.aspectRatio, .fit)
        
        // Change
        viewModel.aspectRatio = .fill
        XCTAssertEqual(viewModel.aspectRatio, .fill)
    }
}
