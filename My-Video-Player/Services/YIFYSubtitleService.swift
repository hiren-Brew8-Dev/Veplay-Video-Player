import Foundation
import SwiftSoup
import Alamofire
import SSZipArchive
import Combine

// MARK: - Models

struct YIFYSubtitle: Identifiable {
    let id = UUID()
    let title: String
    let language: String
    let rating: String
    let url: String // Page URL or download link
    let isDownloadLink: Bool
}

// MARK: - Service

class YIFYSubtitleService: ObservableObject {
    @Published var searchResults: [YIFYSubtitle] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Base URLs
    private let baseURL = "https://yifysubtitles.org"
    private let searchURL = "https://yifysubtitles.org/search?q="
    
    // MARK: - Search
    
    func search(query: String) {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let urlString = searchURL + encodedQuery
        
        isLoading = true
        errorMessage = nil
        searchResults = []
        
        AF.request(urlString).responseString { [weak self] response in
            guard let self = self else { return }
            self.isLoading = false
            
            switch response.result {
            case .success(let html):
                self.parseSearchResults(html: html)
            case .failure(let error):
                self.errorMessage = "Network error: \(error.localizedDescription)"
            }
        }
    }
    
    private func parseSearchResults(html: String) {
        do {
            let doc = try SwiftSoup.parse(html)
            let rows = try doc.select("div.media-body, li.media-body") // Attempt to find list items
            
            var results: [YIFYSubtitle] = []
            
            // Site structure varies, let's try a generic approach for YIFY's list
            // Typically: <div class="media-body"> <h3 class="media-heading">Title</h3> </div>
            
            // If the search result is directly a movie page vs list of movies
            // Let's assume list of movies first
            
            for row in rows {
                if let link = try? row.select("a").first() {
                    let href = try link.attr("href")
                    let title = try link.text()
                    
                    // Simple validation
                    if !href.isEmpty && !title.isEmpty {
                        let fullLink = href.hasPrefix("http") ? href : baseURL + href
                        results.append(YIFYSubtitle(title: title, language: "Movie", rating: "", url: fullLink, isDownloadLink: false))
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.searchResults = results
                if results.isEmpty {
                    self.errorMessage = "No movies found. Try a specific title."
                }
            }
            
        } catch {
            print("Parsing error: \(error)")
            self.errorMessage = "Failed to parse results."
        }
    }
    
    // MARK: - Fetch Subtitles for Movie
    
    func fetchSubtitles(for movieURL: String, completion: @escaping ([YIFYSubtitle]) -> Void) {
        isLoading = true
        
        AF.request(movieURL).responseString { [weak self] response in
            guard let self = self else { return }
            self.isLoading = false
            
            switch response.result {
            case .success(let html):
                let subs = self.parseMoviePage(html: html)
                completion(subs)
            case .failure(let error):
                self.errorMessage = "Failed to load movie page: \(error.localizedDescription)"
                completion([])
            }
        }
    }
    
    private func parseMoviePage(html: String) -> [YIFYSubtitle] {
        var subtitles: [YIFYSubtitle] = []
        do {
            let doc = try SwiftSoup.parse(html)
            // Look for the table
            let rows = try doc.select("tr")
            
            for row in rows {
                let columns = try row.select("td")
                if columns.count >= 3 {
                    let rating = try columns[0].text() // Rating
                    let language = try columns[1].text() // Language
                    
                    // Download link
                    if let link = try? columns[2].select("a").first() {
                         let href = try link.attr("href")
                         // href is usually like /subtitle/1234.zip
                         let fullLink = href.hasPrefix("http") ? href : baseURL + href
                         
                         // Clean title
                         let title = "Subtitle - \(language)"
                         
                         subtitles.append(YIFYSubtitle(title: title, language: language, rating: rating, url: fullLink, isDownloadLink: true))
                    }
                }
            }
        } catch {
            print("Sub parsing error: \(error)")
        }
        return subtitles
    }
    
    // MARK: - Download
    
    func downloadSubtitle(from urlString: String, completion: @escaping (URL?) -> Void) {
        // YIFY links are often zip files
        // URL is likely: https://yifysubtitles.org/subtitle/xxx.zip
        
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        isLoading = true
        
        let destination: URL = FileManager.default.temporaryDirectory.appendingPathComponent("yify_temp.zip")
        
        let request = AF.download(url, to: { _, _ in
            return (destination, [.removePreviousFile, .createIntermediateDirectories])
        })
        
        request.responseData { response in
            self.isLoading = false
            switch response.result {
            case .success:
                // Unzip and find SRT
                if let srtURL = self.processZip(at: destination) {
                    completion(srtURL)
                } else {
                    self.errorMessage = "Failed to extract subtitle."
                    completion(nil)
                }
            case .failure(let error):
                self.errorMessage = "Download failed: \(error.localizedDescription)"
                completion(nil)
            }
        }
    }
    
    private func processZip(at url: URL) -> URL? {
        let unzipDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: unzipDir, withIntermediateDirectories: true, attributes: nil)
        
        let success = SSZipArchive.unzipFile(atPath: url.path, toDestination: unzipDir.path)
        
        if success {
            let enumerator = FileManager.default.enumerator(at: unzipDir, includingPropertiesForKeys: nil)
            var bestFile: URL?
            var maxSize: Int64 = 0
            
            while let file = enumerator?.nextObject() as? URL {
                if file.pathExtension.lowercased() == "srt" {
                    if let attr = try? FileManager.default.attributesOfItem(atPath: file.path),
                       let size = attr[.size] as? Int64, size > maxSize {
                        maxSize = size
                        bestFile = file
                    }
                }
            }
            return bestFile
        }
        return nil
    }
}
