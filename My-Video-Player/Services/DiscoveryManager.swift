import Foundation
import Network
import Combine

class DiscoveryManager: NSObject, ObservableObject {
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isScanning = false
    @Published var permissionDenied = false
    @Published var needsPermission = true // Initial state before check
    
    private var browser: NWBrowser?
    private var cancellables = Set<AnyCancellable>()
    
    struct DiscoveredDevice: Identifiable, Hashable {
        let id: String
        let name: String
        let model: String
        let type: DeviceType
        
        enum DeviceType {
            case chromecast
            case airplay
            case other
        }
    }
    
    override init() {
        super.init()
        checkPermission()
    }
    
    func startScanning() {
        // Ensure browser is cleaned up
        stopScanning()
        
        discoveredDevices.removeAll()
        isScanning = true
        
        // Browsing for Google Cast (_googlecast._tcp)
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_googlecast._tcp", domain: nil)
        browser = NWBrowser(for: descriptor, using: parameters)
        
        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                self?.handleChanges(results: results)
            }
        }
        
        browser?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .failed(let error):
                    print("Discovery error: \(error)")
                    self?.permissionDenied = true
                    self?.isScanning = false
                case .waiting(let error):
                    print("Discovery waiting: \(error)")
                    // This can happen if the network is down or permission is pending/denied
                    // For now, we don't treat it as a hard failure immediately
                    break
                case .ready:
                    self?.needsPermission = false
                    self?.permissionDenied = false
                default:
                    break
                }
            }
        }
        
        browser?.start(queue: .main)
        
        // Auto-stop scanning after 10 seconds if no devices found
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if let self = self, self.discoveredDevices.isEmpty {
                self.stopScanning()
            }
        }
    }
    
    func stopScanning() {
        browser?.cancel()
        isScanning = false
    }
    
    private func handleChanges(results: Set<NWBrowser.Result>) {
        var newDevices: [DiscoveredDevice] = []
        for result in results {
            if case let .service(name, _, _, _) = result.endpoint {
                let id = name // Simple ID for now
                
                // Avoid duplicates
                if !newDevices.contains(where: { $0.id == id }) {
                    newDevices.append(DiscoveredDevice(
                        id: id,
                        name: name,
                        model: "Cast Device",
                        type: .chromecast
                    ))
                }
            }
        }
        self.discoveredDevices = newDevices
    }
    
    private func checkPermission() {
        // There is no direct API, but we can try a dummy browse
        // or just let the first scan trigger it.
        // For UI purposes, we'll assume we need to check.
    }
}
