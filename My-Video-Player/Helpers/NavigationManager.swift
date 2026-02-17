//
//  NavigationManager.swift
// 
//
//  Created by Shivshankar T Tiwari on 04/11/25.
//

import Foundation
import Combine

enum NavigationDestination: Hashable, Identifiable {
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
    
    var id: String {
        switch self {
        case .onboarding1: return "onboarding1"
        case .onboarding2: return "onboarding2"
        case .onboarding3: return "onboarding3"
        case .onboarding4: return "onboarding4"
        case .thanksForDownloading: return "thanksForDownloading"
        case .rating: return "rating"
        case .dashboard: return "dashboard"
        case .paywall(let onboarding): return "paywall_\(onboarding)"
        case .settings: return "settings"
        case .allFolders: return "allFolders"
        case .folderDetail(let folder): return "folder_\(folder.id.uuidString)"
        case .search(let title, _): return "search_\(title)"
        }
    }
}



final class NavigationManager: ObservableObject {
    @Published var path: [NavigationDestination] = []
    @Published var isDashboardRoot: Bool = false
    @Published var fullScreenDestination: NavigationDestination? = nil
    
    // Per-tab paths for Dashboard
    @Published var homePath: [NavigationDestination] = []
    @Published var galleryPath: [NavigationDestination] = []
    @Published var foldersPath: [NavigationDestination] = []
    @Published var searchPath: [NavigationDestination] = []
    
    // Track current tab to know which path to use
    @Published var currentTab: DashboardViewModel.MainTabs = .home
    
    // MARK: - Standard navigation helpers
    
    func push(_ destination: NavigationDestination) {
        print("🧭 push called:", destination)
        HapticsManager.shared.generate(.light)
        
        if destination == .dashboard {
            setDashboardRoot()
            return
        }
        
        // Settings and Paywall should be full screen in Dashboard
        if isDashboardRoot {
            switch destination {
            case .settings, .paywall:
                fullScreenDestination = destination
                return
            default:
                break
            }
        }
        
        // If we are in the dashboard, use tab-specific paths
        if isDashboardRoot {
            pushToCurrentTab(destination)
        } else {
            // Global navigation (Onboarding, Splash, etc.)
            guard path.last != destination else { return }
            path.append(destination)
        }
    }
    
    func setDashboardRoot() {
        print("🧭 Setting Dashboard as Root")
        path.removeAll()
        isDashboardRoot = true
    }
    
    private func pushToCurrentTab(_ destination: NavigationDestination) {
        switch currentTab {
        case .home:
            guard homePath.last != destination else { return }
            homePath.append(destination)
        case .gallery:
            guard galleryPath.last != destination else { return }
            galleryPath.append(destination)
        case .folders:
            guard foldersPath.last != destination else { return }
            foldersPath.append(destination)
        case .search:
            guard searchPath.last != destination else { return }
            searchPath.append(destination)
        }
    }

    func push(_ destinations: [NavigationDestination]) {
        if isDashboardRoot {
            switch currentTab {
            case .home: homePath.append(contentsOf: destinations)
            case .gallery: galleryPath.append(contentsOf: destinations)
            case .folders: foldersPath.append(contentsOf: destinations)
            case .search: searchPath.append(contentsOf: destinations)
            }
        } else {
            path.append(contentsOf: destinations)
        }
    }
    
    func pop() {
        if fullScreenDestination != nil {
            fullScreenDestination = nil
            return
        }
        
        if isDashboardRoot {
            popFromCurrentTab()
        } else if !path.isEmpty {
            path.removeLast()
        }
    }
    
    private func popFromCurrentTab() {
        switch currentTab {
        case .home: if !homePath.isEmpty { homePath.removeLast() }
        case .gallery: if !galleryPath.isEmpty { galleryPath.removeLast() }
        case .folders: if !foldersPath.isEmpty { foldersPath.removeLast() }
        case .search: if !searchPath.isEmpty { searchPath.removeLast() }
        }
    }
    
    func popToRoot() {
        if isDashboardRoot {
            popToRootOfCurrentTab()
        } else {
            path.removeAll()
        }
    }
    
    func popToRootOfCurrentTab() {
        switch currentTab {
        case .home: homePath.removeAll()
        case .gallery: galleryPath.removeAll()
        case .folders: foldersPath.removeAll()
        case .search: searchPath.removeAll()
        }
    }
    
    func setPath(_ destinations: [NavigationDestination]) {
        path = destinations
    }
    
    func pop(to destination: NavigationDestination) {
        // Implementation for tab-specific pop if needed
        if isDashboardRoot {
            // Local pop logic
            popLocally(to: destination)
        } else {
            guard let index = path.firstIndex(of: destination) else { return }
            path = Array(path.prefix(index + 1))
        }
    }
    
    private func popLocally(to destination: NavigationDestination) {
        switch currentTab {
        case .home:
            if let index = homePath.firstIndex(of: destination) {
                homePath = Array(homePath.prefix(index + 1))
            }
        case .gallery:
            if let index = galleryPath.firstIndex(of: destination) {
                galleryPath = Array(galleryPath.prefix(index + 1))
            }
        case .folders:
            if let index = foldersPath.firstIndex(of: destination) {
                foldersPath = Array(foldersPath.prefix(index + 1))
            }
        case .search:
            if let index = searchPath.firstIndex(of: destination) {
                searchPath = Array(searchPath.prefix(index + 1))
            }
        }
    }
    
    // MARK: - Debug
    func debugPrintPath() {
        print("🧭 Current Global Path: \(path)")
        print("🏠 Home Path: \(homePath)")
        print("📁 Folders Path: \(foldersPath)")
    }
}
