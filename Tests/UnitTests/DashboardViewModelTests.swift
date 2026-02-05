import XCTest
@testable import Video_Player

class DashboardViewModelTests: XCTestCase {
    
    var viewModel: DashboardViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = DashboardViewModel()
        
        // Inject mock videos
        let v1 = VideoItem(title: "A Video", duration: 10, creationDate: Date(), fileSizeBytes: 100)
        let v2 = VideoItem(title: "B Video", duration: 20, creationDate: Date().addingTimeInterval(-100), fileSizeBytes: 200)
        viewModel.videos = [v1, v2]
    }
    
    func testSearchFiltering() {
        viewModel.searchText = "B Video"
        
        // Need expectation for Combine pipeline debounce
        let expectation = XCTestExpectation(description: "Debounce")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.viewModel.filteredVideos.count, 1)
            XCTAssertEqual(self.viewModel.filteredVideos.first?.title, "B Video")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSortingDateDesc() {
        viewModel.sortOption = .dateDesc
        // Wait for pipeline
        let expectation = XCTestExpectation(description: "Sort")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // v1 is newer (Date()) vs v2 (Date-100)
            XCTAssertEqual(self.viewModel.filteredVideos.first?.title, "A Video")
            expectation.fulfill()
        }
         wait(for: [expectation], timeout: 1.0)
    }
    
    func testSortingSizeDesc() {
        viewModel.sortOption = .sizeDesc // v2 is 200, v1 is 100
        
        let expectation = XCTestExpectation(description: "SortSize")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertEqual(self.viewModel.filteredVideos.first?.title, "B Video")
             expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
