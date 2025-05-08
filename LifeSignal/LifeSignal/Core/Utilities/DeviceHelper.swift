import Foundation
import UIKit
import Darwin

/// Helper class for device-specific functionality
class DeviceHelper {
    /// Singleton instance
    static let shared = DeviceHelper()

    /// Private initializer for singleton
    private init() {}

    /// Enum representing supported device models
    enum DeviceModel: String {
        // iPhone 13 models
        case iPhone13Mini = "iPhone13,1"
        case iPhone13 = "iPhone13,2"
        case iPhone13Pro = "iPhone13,3"
        case iPhone13ProMax = "iPhone13,4"

        // iPhone 14 models
        case iPhone14 = "iPhone14,7"
        case iPhone14Plus = "iPhone14,8"
        case iPhone14Pro = "iPhone14,2"
        case iPhone14ProMax = "iPhone14,3"

        // iPhone 15 models
        case iPhone15 = "iPhone15,4"
        case iPhone15Plus = "iPhone15,5"
        case iPhone15Pro = "iPhone15,2"
        case iPhone15ProMax = "iPhone15,3"

        // iPhone 16 models (future)
        case iPhone16 = "iPhone16,0"
        case iPhone16Plus = "iPhone16,2"
        case iPhone16Pro = "iPhone16,1"
        case iPhone16ProMax = "iPhone16,3"

        // Simulator and unknown
        case simulator = "i386" // 32-bit simulator
        case simulator64 = "x86_64" // 64-bit simulator
        case simulatorArm64 = "arm64" // Apple Silicon simulator
        case simulatoriPhone13Mini = "simulator-iPhone13,1"
        case simulatoriPhone16Pro = "simulator-iPhone16,1"
        case unknown

        /// Returns the appropriate test phone number for this device model
        var testPhoneNumber: String {
            switch self {
            // iPhone 13 Mini and similar sized devices now use second test user (FLIPPED)
            case .iPhone13Mini, .iPhone13, .iPhone14, .iPhone15, .simulatoriPhone13Mini:
                return "+16505553434" // Test user 2

            // Pro models and larger devices now use first test user (FLIPPED)
            case .iPhone13Pro, .iPhone13ProMax,
                 .iPhone14Pro, .iPhone14ProMax, .iPhone14Plus,
                 .iPhone15Pro, .iPhone15ProMax, .iPhone15Plus,
                 .iPhone16, .iPhone16Plus, .iPhone16Pro, .iPhone16ProMax,
                 .simulatoriPhone16Pro:
                return "+11234567890" // Test user 1

            // Simulators and unknown devices - assign based on simulator type (FLIPPED)
            case .simulator, .simulator64, .simulatorArm64:
                // This is a fallback, but we should be using the specific simulator device cases above
                return "+11234567890" // Default simulator to test user 1

            case .unknown:
                // For unknown devices, default to test user 2 (FLIPPED)
                return "+16505553434"
            }
        }
    }

    /// Get the current device model
    var deviceModel: DeviceModel {
        let identifier = deviceIdentifier

        // Check for simulator
        #if targetEnvironment(simulator)
            // Get the simulated device model from environment
            if let simulatedDeviceInfo = ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] {
                print("Simulator device identifier: \(simulatedDeviceInfo)")

                // Map simulator device to our enum
                if simulatedDeviceInfo == "iPhone13,1" || simulatedDeviceInfo == "iPhone14,4" {
                    return .simulatoriPhone13Mini
                } else if simulatedDeviceInfo == "iPhone16,1" || simulatedDeviceInfo == "iPhone15,2" {
                    return .simulatoriPhone16Pro
                }
            }

            // Check simulator device name as a fallback
            if let simulatorName = ProcessInfo().environment["SIMULATOR_DEVICE_NAME"] {
                print("Simulator device name: \(simulatorName)")

                // Check for iPhone 13 Mini in the name
                if simulatorName.contains("iPhone 13 mini") ||
                   simulatorName.contains("iPhone 12 mini") ||
                   simulatorName.contains("iPhone SE") {
                    return .simulatoriPhone13Mini
                }

                // Check for Pro models
                if simulatorName.contains("Pro") ||
                   simulatorName.contains("iPhone 14 Plus") ||
                   simulatorName.contains("iPhone 15 Plus") ||
                   simulatorName.contains("iPhone 16") {
                    return .simulatoriPhone16Pro
                }
            }

            // Fallback to screen size for simulator
            let screenSize = UIScreen.main.bounds.size
            let minDimension = min(screenSize.width, screenSize.height)
            let maxDimension = max(screenSize.width, screenSize.height)

            print("Simulator screen dimensions: \(screenSize.width) x \(screenSize.height)")

            // iPhone 13 Mini, 12 Mini, SE (2nd gen) - smaller screens
            if minDimension <= 375 && maxDimension <= 812 {
                return .simulatoriPhone13Mini
            }

            // iPhone Pro models typically have larger screens
            if minDimension >= 390 && maxDimension >= 844 {
                return .simulatoriPhone16Pro
            }

            // Last resort fallback based on architecture
            if identifier == "i386" || identifier == "x86_64" {
                return .simulator64
            } else {
                return .simulatorArm64
            }
        #else
            // Physical device detection

            // iPhone 13 models
            if identifier == "iPhone14,4" { return .iPhone13Mini } // Actual identifier for iPhone 13 Mini
            if identifier == "iPhone14,5" { return .iPhone13 }
            if identifier == "iPhone14,2" { return .iPhone13Pro }
            if identifier == "iPhone14,3" { return .iPhone13ProMax }

            // iPhone 14 models
            if identifier == "iPhone14,7" { return .iPhone14 }
            if identifier == "iPhone14,8" { return .iPhone14Plus }
            if identifier == "iPhone15,2" { return .iPhone14Pro }
            if identifier == "iPhone15,3" { return .iPhone14ProMax }

            // iPhone 15 models
            if identifier == "iPhone15,4" { return .iPhone15 }
            if identifier == "iPhone15,5" { return .iPhone15Plus }
            if identifier == "iPhone16,1" { return .iPhone15Pro }
            if identifier == "iPhone16,2" { return .iPhone15ProMax }

            // Fallback for physical devices - check for common patterns
            if identifier.contains("iPhone14,4") { return .iPhone13Mini }
            if identifier.contains("iPhone13,1") { return .iPhone13Mini }

            // For debugging
            print("Physical device identifier: \(identifier)")

            // Fallback based on screen size for physical devices
            if UIDevice.current.userInterfaceIdiom == .phone {
                let screenSize = UIScreen.main.bounds.size
                let minDimension = min(screenSize.width, screenSize.height)
                let maxDimension = max(screenSize.width, screenSize.height)

                // iPhone 13 Mini, 12 Mini, SE (2nd gen) - smaller screens
                if minDimension <= 375 && maxDimension <= 812 {
                    print("Screen size detection: Small iPhone (13 Mini or similar)")
                    return .iPhone13Mini
                }

                // iPhone Pro models typically have larger screens
                if minDimension >= 390 && maxDimension >= 844 {
                    print("Screen size detection: Larger iPhone (Pro model or similar)")
                    return .iPhone16Pro
                }

                // Print screen dimensions for debugging
                print("Screen dimensions: \(screenSize.width) x \(screenSize.height)")
            }
        #endif

        return .unknown
    }

    /// Get the appropriate test phone number for the current device
    var testPhoneNumber: String {
        return deviceModel.testPhoneNumber
    }

    /// Get a human-readable device name for display
    var deviceDisplayName: String {
        #if targetEnvironment(simulator)
            let simulatorModel = ProcessInfo().environment["SIMULATOR_DEVICE_NAME"] ?? "Simulator"
            return "Simulator (\(simulatorModel))"
        #else
            let deviceName = UIDevice.current.name
            let modelName = UIDevice.current.model
            let systemVersion = UIDevice.current.systemVersion

            // Get screen dimensions for additional info
            let screenSize = UIScreen.main.bounds.size
            let screenInfo = "\(Int(screenSize.width))x\(Int(screenSize.height))"

            return "\(modelName) - \(screenInfo) - iOS \(systemVersion)"
        #endif
    }

    /// Get the device identifier (e.g., "iPhone13,1")
    private var deviceIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
