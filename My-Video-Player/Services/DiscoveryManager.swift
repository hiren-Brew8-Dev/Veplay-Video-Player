import Foundation
import Network
import Combine

class DiscoveryManager: NSObject, ObservableObject {
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isScanning = false
    @Published var permissionDenied = false
    @Published var needsPermission = true // Initial state before check
    @Published var localNetworkAccess: LocalNetworkAccess = .unknown
    @Published var lastScanErrorDescription: String?
    
    private var browsers: [NWBrowser] = []
    
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
    }

    func startScanning() {
        stopScanning()
        
        discoveredDevices.removeAll()
        isScanning = true
        lastScanErrorDescription = nil
        localNetworkAccess = .unknown
        permissionDenied = false
        
        let services = ["_googlecast._tcp", "_airplay._tcp"]
        
        for service in services {
            startBrowser(for: service)
        }
        

    }
    
    private func startBrowser(for type: String) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        
        let descriptor = NWBrowser.Descriptor.bonjour(type: type, domain: nil)
        let browser = NWBrowser(for: descriptor, using: parameters)
        
        browser.browseResultsChangedHandler = { [weak self] results, changes in
            DispatchQueue.main.async {
                self?.handleResults(results, for: type)
            }
        }
        
        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleStateUpdate(state)
            }
        }
        
        browser.start(queue: .main)
        browsers.append(browser)
    }
    
    func stopScanning() {
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
        isScanning = false
    }
    
    private func handleResults(_ results: Set<NWBrowser.Result>, for type: String) {
        // This is a bit tricky because we have multiple browsers updating the same list.
        // We should merge them.
        // For simplicity, we'll just append non-duplicates from these results.
        
        // Efficient approach: Re-map all current browsers results would be ideal, 
        // but NWBrowser doesn't give us "all results" easily on demand, only diffs or current set.
        // The results passed here are the *current* set for this browser.
        
        var currentList = discoveredDevices.filter { device in
            // Keep devices that match OTHER types (not the one currently updating)
            if type == "_googlecast._tcp" && device.type == .chromecast { return false }
            if type == "_airplay._tcp" && device.type == .airplay { return false }
            return true
        }
        
        for result in results {
            if case let .service(name, _, _, _) = result.endpoint {
                let deviceType: DiscoveredDevice.DeviceType = (type == "_googlecast._tcp") ? .chromecast : .airplay
                let device = DiscoveredDevice(
                    id: name, // Using name as ID
                    name: name,
                    model: deviceType == .chromecast ? "Chromecast" : "AirPlay Device",
                    type: deviceType
                )
                currentList.append(device)
            }
        }
        
        self.discoveredDevices = currentList.sorted(by: { $0.name < $1.name })
    }
    
    private func handleStateUpdate(_ state: NWBrowser.State) {
        switch state {
        case .failed(let error):
            print("Discovery error: \(error)")
            self.lastScanErrorDescription = String(describing: error)
            if Self.isLocalNetworkDenied(error) {
                self.localNetworkAccess = .denied
                self.permissionDenied = true
                self.needsPermission = false
                self.stopScanning()
            }
        case .waiting(let error):
            print("Discovery waiting: \(error)")
            // Don't overwrite lastScanErrorDescription immediately if it's just a transient wait
            if Self.isLocalNetworkDenied(error) {
                self.localNetworkAccess = .denied
                self.permissionDenied = true
                self.needsPermission = false
                self.stopScanning()
            }
        case .ready:
            self.needsPermission = false
            self.permissionDenied = false
            self.localNetworkAccess = .granted
        default:
            break
        }
    }

    private static func isLocalNetworkDenied(_ error: NWError) -> Bool {
        switch error {
        case .posix(let code):
            return code == .EPERM || code == .EACCES
        case .dns(let code):
             return code == kDNSServiceErr_PolicyDenied
        default:
            return false
        }
    }
}
