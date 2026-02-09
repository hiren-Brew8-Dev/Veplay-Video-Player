import Foundation
import Combine

struct SubtitleItem: Identifiable, Equatable {
    let id = UUID()
    let index: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

struct SubtitleTrack: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let url: URL? // nil for embedded?
}

class SubtitleManager: ObservableObject {
    @Published var subtitles: [SubtitleItem] = []
    @Published var currentSubtitle: String = ""
    @Published var isEnabled: Bool = true
    @Published var offsetDelay: TimeInterval = 0.0
    
    // Track Management
    @Published var availableTracks: [SubtitleTrack] = []
    @Published var selectedTrackIndex: Int = -1 // -1 = Disabled, 0...N = Tracks
    
    // Styling
    @Published var fontSize: Double = 16.0
    @Published var fontColor: String = "White" // White, Yellow, Cyan
    @Published var showBackground: Bool = true
    
    // Performance optimization: track last index
    private var lastSearchIndex: Int = 0
    
    // MARK: - Initialization
    
    init() {
        // Load persisted delay and style from UserDefaults
        if let savedDelay = UserDefaults.standard.object(forKey: "subtitleDelay") as? Double {
            self.offsetDelay = savedDelay / 1000.0 // Convert from ms to seconds
        }
        if let size = UserDefaults.standard.object(forKey: "subFontSize") as? Double {
            self.fontSize = size
        }
        if let color = UserDefaults.standard.string(forKey: "subFontColor") {
            self.fontColor = color
        }
        if let bg = UserDefaults.standard.object(forKey: "subShowBg") as? Bool {
            self.showBackground = bg
        }
    }
    
    // MARK: - Parsing
    
    func loadSubtitle(from url: URL, trackName: String? = nil) {
        // Fix: Permission Error (Code=257). 
        // We must access the security scoped resource. 
        // Best practice: Copy to temp so we own it.
        
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            parseSRT(content)
            
            // Add to tracks if not present 
            // NOTE: We store the ORIGINAL URL for reference, but next time we load,
            // we will need to access it again. 
            // Ideally, we'd cache the copied temp URL, but the user might select the same file again.
            // Since `selectTrack` calls this `loadSubtitle` method, and `startAccessing...` is here, 
            // re-selection should work fine now.
            
            let name = trackName ?? url.lastPathComponent
            if !availableTracks.contains(where: { $0.url == url }) {
                let track = SubtitleTrack(name: name, url: url)
                availableTracks.append(track)
                // Set the newly added track as selected
                selectedTrackIndex = availableTracks.count - 1
            } else {
                // If track already exists, find and select it
                if let existingIndex = availableTracks.firstIndex(where: { $0.url == url }) {
                    selectedTrackIndex = existingIndex
                }
            }
            
            // IMPORTANT: Enable subtitles after loading
            isEnabled = true
            
        } catch {
            print("Failed to load subtitle: \(error)")
            // Try different encoding (Windows-1252 / Latin1)
            if let content = try? String(contentsOf: url, encoding: .windowsCP1252) {
                 parseSRT(content)
                 isEnabled = true
            } else if let content = try? String(contentsOf: url, encoding: .ascii) {
                 parseSRT(content)
                 isEnabled = true
            }
        }
    }
    
    func selectTrack(at index: Int) {
        if index == -1 {
            // Disable subtitles
            isEnabled = false
            selectedTrackIndex = -1
            subtitles.removeAll()
            currentSubtitle = ""
            return
        }
        
        guard index >= 0 && index < availableTracks.count else { return }
        
        // Optimization: Don't reload if already selected and loaded
        if selectedTrackIndex == index && !subtitles.isEmpty && isEnabled {
            // Track is already active, no need to reload
            return
        }
        
        // Clear current subtitle before loading new track
        currentSubtitle = ""
        
        // Load the selected track (this will set isEnabled = true)
        if let url = availableTracks[index].url {
            loadSubtitle(from: url, trackName: availableTracks[index].name)
        } else {
            isEnabled = true
        }
        selectedTrackIndex = index
    }
    
    func parseSRT(_ content: String) {
        var parsedItems: [SubtitleItem] = []
        let lines = content.components(separatedBy: .newlines)
        
        var currentIndex: Int?
        var startTime: TimeInterval?
        var endTime: TimeInterval?
        var textBuffer: String = ""
        
        // Simple State Machine
        // 0: Look for index
        // 1: Look for time
        // 2: Accumulate text
        var state = 0
        
        let timeRegex = try! NSRegularExpression(pattern: "(\\d{2}):(\\d{2}):(\\d{2}),(\\d{3}) --> (\\d{2}):(\\d{2}):(\\d{2}),(\\d{3})")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty {
                if let idx = currentIndex, let start = startTime, let end = endTime, !textBuffer.isEmpty {
                    parsedItems.append(SubtitleItem(index: idx, startTime: start, endTime: end, text: textBuffer))
                }
                // Reset
                currentIndex = nil
                startTime = nil
                endTime = nil
                textBuffer = ""
                state = 0
                continue
            }
            
            if state == 0 {
                if let idx = Int(trimmed) {
                    currentIndex = idx
                    state = 1
                }
            } else if state == 1 {
                if let match = timeRegex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    // Extract times
                    // Basic parsing logic needed here for groups
                    startTime = parseTime(line, match: match, startGroup: 1)
                    endTime = parseTime(line, match: match, startGroup: 5)
                    state = 2
                } else {
                    // Fallback reset if expected time line is garbage
                   state = 0 
                }
            } else if state == 2 {
                if textBuffer.isEmpty {
                    textBuffer = trimmed
                } else {
                    textBuffer += "\n" + trimmed
                }
            }
        }
        
        // Final item
        if let idx = currentIndex, let start = startTime, let end = endTime, !textBuffer.isEmpty {
            parsedItems.append(SubtitleItem(index: idx, startTime: start, endTime: end, text: textBuffer))
        }
        
        DispatchQueue.main.async {
            self.subtitles = parsedItems.sorted(by: { $0.startTime < $1.startTime })
            self.lastSearchIndex = 0
        }
    }
    
    private func parseTime(_ line: String, match: NSTextCheckingResult, startGroup: Int) -> TimeInterval {
        let h = Double((line as NSString).substring(with: match.range(at: startGroup))) ?? 0
        let m = Double((line as NSString).substring(with: match.range(at: startGroup + 1))) ?? 0
        let s = Double((line as NSString).substring(with: match.range(at: startGroup + 2))) ?? 0
        let ms = Double((line as NSString).substring(with: match.range(at: startGroup + 3))) ?? 0
        
        return (h * 3600) + (m * 60) + s + (ms / 1000.0)
    }
    
    // MARK: - Update Logic
    
    func update(currentTime: TimeInterval, audioDelay: TimeInterval = 0) {
        guard isEnabled, !subtitles.isEmpty else {
            if !currentSubtitle.isEmpty { currentSubtitle = "" }
            return
        }
        
        // Calculate adjusted time: 
        // 1. Subtract offsetDelay (user's manual subtitle adjustment)
        // 2. Subtract audioDelay (to sync with delayed audio)
        let adjustedTime = currentTime - offsetDelay - audioDelay
        
        // Optimization: Start searching from last known index
        // If adjustedTime < subtitles[last].start, we jumped back, reset search
        if lastSearchIndex < subtitles.count && adjustedTime < subtitles[lastSearchIndex].startTime {
            lastSearchIndex = 0
        }
        
        var foundText = ""
        
        // Linear search forward
        for i in lastSearchIndex..<subtitles.count {
            let item = subtitles[i]
            if adjustedTime >= item.startTime && adjustedTime <= item.endTime {
                foundText = item.text
                lastSearchIndex = i 
                break
            } else if item.startTime > adjustedTime {
                // Future subtitle, stop search
                break
            }
        }
        
        if currentSubtitle != foundText {
            currentSubtitle = foundText
        }
    }
    
    func clear() {
        subtitles.removeAll()
        currentSubtitle = ""
        lastSearchIndex = 0
    }
}
