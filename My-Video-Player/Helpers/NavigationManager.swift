//
//  NavigationManager.swift
// 
//
//  Created by Shivshankar T Tiwari on 04/11/25.
//

import Foundation
import Combine

enum NavigationDestination: Hashable {
    case onboarding1
    case onboarding2
    case onboarding3
    case onboarding4
    case thanksForDownloading
    case rating
    case dashboard
    case paywall(isFromOnboarding: Bool)
    case settings
    case allFolders
    case folderDetail(Folder)
    case search(contextTitle: String, initialVideos: [VideoItem]?)
}



final class NavigationManager: ObservableObject {
    @Published var path: [NavigationDestination] = []
    
    // MARK: - Standard navigation helpers
    
    func push(_ destination: NavigationDestination) {
        print("🧭 push called:", destination)
        HapticsManager.shared.generate(.light)
        guard path.last != destination else { return }
        path.append(destination)
        print("🧭 path now:", path)
    }

    func push(_ destinations: [NavigationDestination]) {
        path.append(contentsOf: destinations)
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        path.removeAll()
    }
    
    func setPath(_ destinations: [NavigationDestination]) {
        path = destinations
    }
    
    func pop(to destination: NavigationDestination) {
        guard let index = path.firstIndex(of: destination) else {
            return
        }
        path = Array(path.prefix(index + 1))
    }
    
    // MARK: - Debug
    func debugPrintPath() {
        print("🧭 Current Path: \(path)")
    }
}
