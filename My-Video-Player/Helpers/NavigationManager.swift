//
//  NavigationManager.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 13/02/26.
//

import SwiftUI
import Combine

enum NavigationDestination: Hashable {
    case onboarding1
    case onboarding2
    case onboarding3
    case rating
    case dashboard
}

class NavigationManager: ObservableObject {
    @Published var path = NavigationPath()
    
    func push(_ destination: NavigationDestination) {
        path.append(destination)
    }
    
    func pop() {
        path.removeLast()
    }
    
    func popToRoot() {
        path.removeLast(path.count)
    }
}
