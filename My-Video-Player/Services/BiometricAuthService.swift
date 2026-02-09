import LocalAuthentication
import SwiftUI
import Combine

class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()
    
    @Published var isUnlocked: Bool = false
    @Published var error: String? = nil
    
    func authenticate(completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Check if device supports FaceID/TouchID
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Unlock your App"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                        completion(true)
                    } else {
                        self.error = authenticationError?.localizedDescription ?? "Authentication failed"
                        self.isUnlocked = false
                        completion(false)
                    }
                }
            }
        } else {
            // Fallback for Simulator or devices without biometrics
            print("Biometrics not available: \(String(describing: error))")
            // For demo purposes, we'll just allow it or maybe require a simple mock PIN
            // In a real app, fallback to passcode
            self.isUnlocked = true
            completion(true) 
        }
    }
    
    func lock() {
        self.isUnlocked = false
    }
}
