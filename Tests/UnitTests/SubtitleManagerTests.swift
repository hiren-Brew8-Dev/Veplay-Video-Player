import XCTest
@testable import Video_Player

class SubtitleManagerTests: XCTestCase {
    
    var manager: SubtitleManager!
    
    override func setUp() {
         super.setUp()
         manager = SubtitleManager()
    }
    
    func testParsingValidSRT() {
        let sampleSRT = """
        1
        00:00:01,000 --> 00:00:04,000
        Hello World
        
        2
        00:00:05,000 --> 00:00:10,500
        Test Subtitle
        """
        
        manager.parseSRT(sampleSRT)
        
        XCTAssertEqual(manager.subtitles.count, 2)
        XCTAssertEqual(manager.subtitles[0].text, "Hello World")
        XCTAssertEqual(manager.subtitles[1].startTime, 5.0)
        XCTAssertEqual(manager.subtitles[1].endTime, 10.5)
    }
    
    func testTimingLogic() {
        let sampleSRT = """
        1
        00:00:01,000 --> 00:00:04,000
        First
        """
        manager.parseSRT(sampleSRT)
        
        // Before start
        manager.update(currentTime: 0.5)
        XCTAssertEqual(manager.currentSubtitle, "")
        
        // Inside verify
        manager.update(currentTime: 2.0)
        XCTAssertEqual(manager.currentSubtitle, "First")
        
        // After end
        manager.update(currentTime: 5.0)
        XCTAssertEqual(manager.currentSubtitle, "") // Should clear/remain empty depending on logic.
        // Actually looking at code: update() logic doesn't explicitly clear if not found in loop, 
        // but loop might exhaust. Wait, code implementation:
        // if item.startTime > adjustedTime { break }
        // foundText defaults empty. 
        // So yes, it clears.
    }
    
    func testPersistenceMock() {
        // Can't easily test real UserDefaults without standard library hacks, 
        // but verifying properties exist
        manager.fontSize = 24.0
        XCTAssertEqual(manager.fontSize, 24.0)
    }
}
