import Foundation
import Combine
import Alamofire

@preconcurrency import Foundation

// MARK: - Models (Renamed & Sendable)

struct OSSubtitleItem: Identifiable, Decodable, Sendable {
    let id: String
    let attributes: OSAttributes
    
    struct OSAttributes: Decodable, Sendable {
        let subtitle_id: String
        let language: String
        let format: String?
        let url: String? 
        let feature_details: OSFeatureDetails?
        let files: [OSFile]?
    }
    
    struct OSFeatureDetails: Decodable, Sendable {
        let title: String
        let year: Int
    }
    
    struct OSFile: Decodable, Sendable {
        let file_id: Int
        let file_name: String
    }
}

struct OSLinkResponse: Decodable, Sendable {
    let link: String
}

struct OSSearchResponseRoot: Decodable, Sendable {
    let data: [OSSubtitleItem]
}

struct OSHistoryItem: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let url: URL
    let date: Date
}

// MARK: - Service

// MARK: - Auth Models

struct OSLoginPayload: Encodable, Sendable {
    let username: String
    let password: String
}

struct OSLoginResponse: Decodable, Sendable {
    let token: String
    let user: OSUser?
    
    struct OSUser: Decodable, Sendable {
        let id: Int
        let username: String
    }
}

// MARK: - Service

@MainActor
class OpenSubtitlesService: ObservableObject {
    @Published var searchResults: [OSSubtitleItem] = []
    @Published var downloadedFiles: [OSHistoryItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isLoggedIn: Bool = false
    
    // API CONFIG
    private let apiKey = "YOUR_API_KEY_HERE"
    private var userAgent = "VideoPlayer v1.0"
    private let baseURL = "https://api.opensubtitles.com/api/v1"
    
    // Auth State
    private var authToken: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        refreshDownloadedFiles()
    }
    
    // MARK: - Configuration
    
    func configure(userAgent: String) {
        self.userAgent = userAgent
    }
    
    // MARK: - Authentication
    
    func login(username: String, password: String) {
        guard let url = URL(string: "\(baseURL)/login") else { return }
        let payload = OSLoginPayload(username: username, password: password)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            errorMessage = "Encoding Error: \(error.localizedDescription)"
            return
        }
        
        isLoading = true
        
        AF.request(request)
            .validate()
            .responseData { response in
                Task { @MainActor in
                    self.isLoading = false
                    switch response.result {
                    case .success(let data):
                        do {
                            let loginResp = try JSONDecoder().decode(OSLoginResponse.self, from: data)
                            self.authToken = loginResp.token
                            self.isLoggedIn = true
                            print("OpenSubtitles Logged in as \(loginResp.user?.username ?? "User")")
                        } catch {
                            self.errorMessage = "Login Failed: \(error.localizedDescription)"
                        }
                    case .failure(let error):
                        self.errorMessage = "Login Network Error: \(error.localizedDescription)"
                    }
                }
            }
    }
    
    // MARK: - Search
    
    func search(query: String, language: String = "en") {
        guard !query.isEmpty else { return }
        
        isLoading = true
        errorMessage = nil
        searchResults = []
        
        // MOCK MODE
        if apiKey == "YOUR_API_KEY_HERE" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.mockSearch(query: query)
                self.isLoading = false
            }
            return
        }
        
        var headers: HTTPHeaders = [
            "Api-Key": apiKey,
            "User-Agent": userAgent,
            "Content-Type": "application/json"
        ]
        
        if let token = authToken {
            headers.add(name: "Authorization", value: "Bearer \(token)")
        }
        
        let parameters: [String: String] = [
            "query": query,
            "languages": language
        ]
        
        // Manual Data Decoding to fix Concurrency/Sendable issues
        AF.request("\(baseURL)/subtitles", parameters: parameters, headers: headers)
            .validate()
            .responseData { response in
                Task { @MainActor in
                    self.isLoading = false
                    switch response.result {
                    case .success(let data):
                        do {
                            let wrapper = try JSONDecoder().decode(OSSearchResponseRoot.self, from: data)
                            self.searchResults = wrapper.data
                        } catch {
                            self.errorMessage = "Decoding Error: \(error.localizedDescription)"
                            print("OS Decode Error: \(error)")
                        }
                    case .failure(let error):
                        self.errorMessage = "Network Error: \(error.localizedDescription)"
                    }
                }
            }
    }
    
    // MARK: - Download
    
    func downloadSubtitle(fileId: Int, fileName: String, completion: @escaping (URL?) -> Void) {
        isLoading = true
        
        // MOCK MODE
        if apiKey == "YOUR_API_KEY_HERE" {
           DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
              self.mockDownload(fileId: fileId, fileName: fileName, completion: completion)
              self.isLoading = false
           }
           return
        }
        
        var headers: HTTPHeaders = [
            "Api-Key": apiKey,
            "User-Agent": userAgent,
            "Content-Type": "application/json"
        ]
        
        if let token = authToken {
            headers.add(name: "Authorization", value: "Bearer \(token)")
        }
        
        let body: [String: Int] = ["file_id": fileId]
        
        // Manual Data Decoding
        AF.request("\(baseURL)/download", method: .post, parameters: body, encoder: JSONParameterEncoder.default, headers: headers)
            .validate()
            .responseData { response in
                Task { @MainActor in
                    switch response.result {
                    case .success(let data):
                        do {
                            let downloadResp = try JSONDecoder().decode(OSLinkResponse.self, from: data)
                            self.performFileDownload(from: downloadResp.link, fileName: fileName, completion: completion)
                        } catch {
                            self.isLoading = false
                            self.errorMessage = "Decoding Error: \(error.localizedDescription)"
                        }
                    case .failure(let error):
                        self.isLoading = false
                        self.errorMessage = "Link Error: \(error.localizedDescription)"
                        completion(nil)
                    }
                }
            }
    }
    
    private func performFileDownload(from link: String, fileName: String, completion: @escaping (URL?) -> Void) {
        let destination: DownloadRequest.Destination = { _, _ in
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let subsDir = docs.appendingPathComponent("Subtitles")
            try? FileManager.default.createDirectory(at: subsDir, withIntermediateDirectories: true)
            
            var finalName = fileName
            if !finalName.hasSuffix(".srt") { finalName += ".srt" }
            
            let fileUrl = subsDir.appendingPathComponent(finalName)
            return (fileUrl, [.removePreviousFile, .createIntermediateDirectories])
        }
        
        AF.download(link, to: destination)
            .validate()
            .response { response in
                self.isLoading = false
                if let error = response.error {
                    self.errorMessage = "Download Error: \(error.localizedDescription)"
                    completion(nil)
                } else {
                    self.refreshDownloadedFiles()
                    completion(response.fileURL)
                }
            }
    }
    
    // MARK: - Local Files
    
    func refreshDownloadedFiles() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let subsDir = docs.appendingPathComponent("Subtitles")
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: subsDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else {
            downloadedFiles = []
            return
        }
        
        self.downloadedFiles = files.compactMap { url in
            let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
            let date = attr?[.creationDate] as? Date ?? Date()
            return OSHistoryItem(name: url.lastPathComponent, url: url, date: date)
        }.sorted(by: { $0.date > $1.date }) // Newest first
    }
    
    func deleteFile(at indexSet: IndexSet) {
        indexSet.forEach { index in
            let file = downloadedFiles[index]
            try? FileManager.default.removeItem(at: file.url)
        }
        refreshDownloadedFiles()
    }
    
    // MARK: - Mocks
    
    private func mockSearch(query: String) {
        self.searchResults = [
            OSSubtitleItem(id: "1", attributes: .init(subtitle_id: "1", language: "en", format: "srt", url: nil, feature_details: .init(title: "\(query) 2023 HDRip", year: 2023), files: [.init(file_id: 101, file_name: "\(query)_2023.srt")])),
            OSSubtitleItem(id: "2", attributes: .init(subtitle_id: "2", language: "hi", format: "srt", url: nil, feature_details: .init(title: "\(query) - Hindi Dub", year: 2023), files: [.init(file_id: 102, file_name: "\(query)_Hindi.srt")])),
            OSSubtitleItem(id: "3", attributes: .init(subtitle_id: "3", language: "es", format: "srt", url: nil, feature_details: .init(title: "\(query) - Spanish", year: 2023), files: [.init(file_id: 103, file_name: "\(query)_Spanish.srt")]))
        ]
    }
    
    private func mockDownload(fileId: Int, fileName: String, completion: @escaping (URL?) -> Void) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let subsDir = docs.appendingPathComponent("Subtitles")
        try? FileManager.default.createDirectory(at: subsDir, withIntermediateDirectories: true)
        
        var finalName = fileName
        if !finalName.hasSuffix(".srt") { finalName += ".srt" }
        let fileUrl = subsDir.appendingPathComponent(finalName)
        
        let content = """
        1
        00:00:01,000 --> 00:00:04,000
        Mock Subtitle for \(fileName)
        ID: \(fileId)
        
        2
        00:00:05,000 --> 00:00:08,000
        Downloaded successfully.
        """
        
        try? content.write(to: fileUrl, atomically: true, encoding: .utf8)
        refreshDownloadedFiles()
        completion(fileUrl)
    }
}
