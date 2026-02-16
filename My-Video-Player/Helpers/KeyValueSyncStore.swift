//
//  KeyValueSyncStore.swift
//  My-Video-Player
//
//  Created by Shivshankar T Tiwari on 16/02/26.
//

import Foundation

final class KeyValueSyncStore {

    static let shared = KeyValueSyncStore()

    private let local = UserDefaults.standard
    private let cloud = NSUbiquitousKeyValueStore.default

    private init() {}
    
    // MARK: - Read

    func array(forKey key: String) -> [Int]? {
        if let cloudValue = cloud.array(forKey: key) as? [Int] {
            local.set(cloudValue, forKey: key)
            return cloudValue
        }
        return local.array(forKey: key) as? [Int]
    }

    func bool(forKey key: String) -> Bool {
        if cloud.object(forKey: key) != nil {
            let value = cloud.bool(forKey: key)
            local.set(value, forKey: key)
            return value
        }
        return local.bool(forKey: key)
    }

    // MARK: - Write

    func set(_ value: [Int], forKey key: String) {
        local.set(value, forKey: key)
        cloud.set(value, forKey: key)
        cloud.synchronize()
    }

    func set(_ value: Bool, forKey key: String) {
        local.set(value, forKey: key)
        cloud.set(value, forKey: key)
        cloud.synchronize()
    }

    // MARK: - Reset (testing only)

    func reset(key: String) {
        local.removeObject(forKey: key)
        cloud.removeObject(forKey: key)
        cloud.synchronize()
    }
}
