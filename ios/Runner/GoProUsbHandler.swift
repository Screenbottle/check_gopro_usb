import Flutter
import Network
import NetworkExtension

class GoProUsbHandler: NSObject {
    static let methodChannelName = "gopro_usb/methods"
    static let eventChannelName = "gopro_usb/events"
    
    private weak var eventSink: FlutterEventSink?
    private var usbMonitorTimer: Timer?
    
    static func register(with controller: FlutterViewController) {
        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        let eventChannel = FlutterEventChannel(
            name: eventChannelName,
            binaryMessenger: controller.binaryMessenger
        )
        
        let handler = GoProUsbHandler()
        
        methodChannel.setMethodCallHandler { call, result in
            handler.handle(call, result: result)
        }
        
        eventChannel.setStreamHandler(handler)
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isGoProConnected":
            result(isGoProConnected())
        case "discoverGoProIP":
            discoverGoProIP(result: result)
        case "bindToGoProNetwork":
            bindToGoProNetwork(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func isGoProConnected() -> String? {
        // On iOS, we check if we can reach the GoPro IP
        // This is a simplified check - on USB-C iPhones, the GoPro will be reachable via USB
        let goProIP = "172.28.183.51"
        return canReachIP(goProIP) ? "GoPro Hero 13 Black (iOS)" : nil
    }
    
    private func discoverGoProIP(result: @escaping FlutterResult) {
        // On iOS, we use Bonjour (mDNS) to discover the GoPro
        let browser = NetServiceBrowser()
        var foundService = false
        
        let delegate = GoProServiceBrowserDelegate { service in
            foundService = true
            
            // Extract serial number from service name
            // Service name typically contains the serial number like "C3601370011883"
            let serviceName = service.name
            NSLog("GoPro: Found service: \(serviceName)")
            
            if let serialNumber = self.extractSerialNumber(from: serviceName) {
                let ip = self.constructIPFromSerial(serialNumber)
                NSLog("GoPro: Serial: \(serialNumber), Constructed IP: \(ip)")
                result(ip)
            } else {
                // Fallback to default IP if we can't extract serial
                NSLog("GoPro: Could not extract serial, using fallback IP")
                result("172.28.183.51")
            }
            
            browser.stop()
        }
        
        browser.delegate = delegate
        browser.searchForServices(
            ofType: "_gopro-web._tcp",
            inDomain: "local."
        )
        
        // Stop after 10 seconds if not found
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if !foundService {
                NSLog("GoPro: Service discovery timeout, using fallback IP")
                browser.stop()
                result("172.28.183.51") // Fallback IP
            }
        }
    }
    
    private func bindToGoProNetwork(result: @escaping FlutterResult) {
        // On iOS 14+, we can use Network framework to bind to specific interfaces
        // For USB-C iPhones with USB networking enabled, this happens automatically
        
        if #available(iOS 14.0, *) {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                // Check if we have a path to the GoPro
                let hasUSBNetwork = path.availableInterfaces.contains { interface in
                    // USB network interfaces typically have specific characteristics
                    return interface.type == .cellular || interface.type == .wifi
                }
                
                result(hasUSBNetwork || path.status == .satisfied)
                monitor.cancel()
            }
            
            let queue = DispatchQueue(label: "com.gopro.network")
            monitor.start(queue: queue)
        } else {
            result(false)
        }
    }
    
    private func canReachIP(_ ip: String) -> Bool {
        // Simple IP reachability check
        // This is a basic implementation - in production, use more sophisticated checks
        if #available(iOS 14.0, *) {
            let host = NWEndpoint.Host(ip)
            let monitor = NWPathMonitor(scopes: [.interface(nil)])
            
            var isReachable = false
            monitor.pathUpdateHandler = { path in
                isReachable = path.status == .satisfied
            }
            
            let queue = DispatchQueue(label: "com.gopro.reachability")
            monitor.start(queue: queue)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                monitor.cancel()
            }
            
            return isReachable
        }
        
        return false
    }
    
    private func extractSerialNumber(from serviceName: String) -> String? {
        // Service name contains the serial number
        // Example: "C3601370011883" or in format like "GoPro-C3601370011883"
        NSLog("GoPro: Extracting serial from: \(serviceName)")
        
        // Look for 14-character sequence of digits/letters (typical serial number format)
        let pattern = "[A-Z0-9]{14}"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(serviceName.startIndex..., in: serviceName)
            if let match = regex.firstMatch(in: serviceName, options: [], range: range) {
                if let matchRange = Range(match.range, in: serviceName) {
                    let serial = String(serviceName[matchRange])
                    return serial
                }
            }
        }
        
        return nil
    }
    
    private func constructIPFromSerial(_ serial: String) -> String {
        // Extract last 3 digits from serial number
        let lastThreeDigits = String(serial.suffix(3))
        
        // Construct IP: 172.2X.1YZ.51 where XYZ are the last three digits
        let chars = Array(lastThreeDigits)
        if chars.count >= 3 {
            let x = chars[0]
            let y = chars[1]
            let z = chars[2]
            
            let ip = "172.2\(x).1\(y)\(z).51"
            NSLog("GoPro: IP constructed: \(ip) from serial: \(serial)")
            
            return ip
        }
        
        // Fallback if we can't parse
        return "172.28.183.51"
    }
}

// MARK: - Bonjour Service Browser Delegate
class GoProServiceBrowserDelegate: NSObject, NetServiceBrowserDelegate {
    typealias ServiceFoundCallback = (NetService) -> Void
    let onServiceFound: ServiceFoundCallback
    
    init(onServiceFound: @escaping ServiceFoundCallback) {
        self.onServiceFound = onServiceFound
    }
    
    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind service: NetService,
        moreComing: Bool
    ) {
        if service.name.lowercased().contains("gopro") {
            onServiceFound(service)
        }
    }
    
    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        NSLog("GoPro Bonjour search failed: \(errorDict)")
    }
}
