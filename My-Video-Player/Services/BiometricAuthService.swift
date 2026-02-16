import LocalAuthentication
import SwiftUI
import Combine

/// Biometric authentication service using iOS system authentication (Face ID/Touch ID + Device Passcode)
class BiometricAuthService: ObservableObject {
    static let shared = BiometricAuthService()
    
    @Published var isUnlocked: Bool = false
    @Published var error: String? = nil
    
    private init() {}
    
    /// Check if device has any authentication method set up (Face ID/Touch ID OR device passcode)
    func canAuthenticate() -> (canAuth: Bool, errorMessage: String?) {
        let context = LAContext()
        var error: NSError?
        
        // Check if device supports authentication (biometrics OR passcode)
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return (true, nil)
        } else {
            // Device has NO security set up
            let message: String
            if let laError = error as? LAError {
                switch laError.code {
                case .passcodeNotSet:
                    message = "No device security found. Please set up Face ID, Touch ID, or a passcode in your iPhone Settings to use App Lock."
                case .biometryNotAvailable:
                    message = "No device security found. Please set up a passcode in your iPhone Settings to use App Lock."
                default:
                    message = "Device authentication is not available. Please set up security in your iPhone Settings."
                }
            } else {
                message = "Device authentication is not available. Please set up security in your iPhone Settings."
            }
            return (false, message)
        }
    }
    
    /// Authenticate using iOS system authentication (Face ID/Touch ID with passcode fallback)
    func authenticate(reason: String = "Unlock your App", completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        
        // Use .deviceOwnerAuthentication which tries biometrics first, then falls back to device passcode
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { [weak self] success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        self?.isUnlocked = true
                        self?.error = nil
                        completion(true)
                    } else {
                        // User cancelled or authentication failed
                        self?.isUnlocked = false
                        if let laError = authenticationError as? LAError {
                            switch laError.code {
                            case .userCancel, .systemCancel, .appCancel:
                                self?.error = nil // Don't show error for cancellation
                            default:
                                self?.error = laError.localizedDescription
                            }
                        }
                        completion(false)
                    }
                }
            }
        } else {
            // No authentication available - should not happen if canAuthenticate() was checked first
            DispatchQueue.main.async { [weak self] in
                self?.isUnlocked = false
                self?.error = "Device authentication is not available"
                completion(false)
            }
        }
    }
    
    /// Lock the app
    func lock() {
        isUnlocked = false
    }
}
