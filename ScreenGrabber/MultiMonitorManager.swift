//
//  MultiMonitorManager.swift
//  ScreenGrabber
//
//  Multi-Monitor Control - Advanced display selection
//

import Foundation
import AppKit
import ScreenCaptureKit

class MultiMonitorManager: ObservableObject {
    static let shared = MultiMonitorManager()

    @Published var availableDisplays: [Display] = []
    @Published var selectedDisplay: Display?
    @Published var rememberDisplayPreference = true

    private let selectedDisplayKey = "selectedDisplayID"

    private init() {
        refreshDisplays()
        loadSelectedDisplay()
    }

    // MARK: - Display Model

    struct Display: Identifiable, Codable, Equatable {
        let id: String // Display ID as string
        var name: String
        var width: Int
        var height: Int
        var isPrimary: Bool
        var position: CGPoint // Position in global coordinate space
        var frame: CGRect

        var displayID: CGDirectDisplayID {
            return CGDirectDisplayID(UInt32(id) ?? 0)
        }

        var resolution: String {
            return "\(width) × \(height)"
        }

        var aspectRatio: String {
            let gcd = greatestCommonDivisor(width, height)
            let ratioW = width / gcd
            let ratioH = height / gcd
            return "\(ratioW):\(ratioH)"
        }

        var description: String {
            let primary = isPrimary ? " (Primary)" : ""
            return "\(name) - \(resolution)\(primary)"
        }

        private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
            return b == 0 ? a : greatestCommonDivisor(b, a % b)
        }
    }

    // MARK: - Display Detection

    func refreshDisplays() {
        var displays: [Display] = []

        // Get all active displays
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(0, nil, &displayCount)

        if result == .success && displayCount > 0 {
            let displayArray = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: Int(displayCount))
            defer { displayArray.deallocate() }

            result = CGGetActiveDisplayList(displayCount, displayArray, &displayCount)

            if result == .success {
                for i in 0..<Int(displayCount) {
                    let displayID = displayArray[i]
                    if let display = createDisplay(from: displayID) {
                        displays.append(display)
                    }
                }
            }
        }

        DispatchQueue.main.async {
            self.availableDisplays = displays.sorted { $0.isPrimary && !$1.isPrimary }

            // Set primary display as default if none selected
            if self.selectedDisplay == nil {
                self.selectedDisplay = displays.first { $0.isPrimary }
            }
        }
    }

    private func createDisplay(from displayID: CGDirectDisplayID) -> Display? {
        let bounds = CGDisplayBounds(displayID)

        // Get display name
        var displayName = "Display \(displayID)"

        if #available(macOS 10.15, *) {
            if let info = infoForCGDirectDisplayID(displayID) {
                displayName = info["displayProductName"] as? String ?? displayName
            }
        }

        // Check if this is the primary display
        let isPrimary = CGDisplayIsMain(displayID) != 0

        return Display(
            id: String(displayID),
            name: displayName,
            width: Int(bounds.width),
            height: Int(bounds.height),
            isPrimary: isPrimary,
            position: bounds.origin,
            frame: bounds
        )
    }

    private func infoForCGDirectDisplayID(_ displayID: CGDirectDisplayID) -> [String: Any]? {
        var infoDict: [String: Any]?

        if let info = IODisplayCreateInfoDictionary(IOServicePortFromCGDisplayID(displayID), IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as? [String: Any] {
            if let names = info[kDisplayProductName] as? [String: String] {
                // Get English name or first available
                if let englishName = names["en_US"] ?? names.values.first {
                    infoDict = ["displayProductName": englishName]
                }
            }
        }

        return infoDict
    }

    private func IOServicePortFromCGDisplayID(_ displayID: CGDirectDisplayID) -> io_service_t {
        var servicePort: io_service_t = 0
        var iter: io_iterator_t = 0

        let matching = IOServiceMatching("IODisplayConnect")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter)

        if result == KERN_SUCCESS {
            var service = IOIteratorNext(iter)

            while service != 0 {
                let info = IODisplayCreateInfoDictionary(service, IOOptionBits(kIODisplayOnlyPreferredName)).takeRetainedValue() as? [String: Any]

                if let vendorID = info?[kDisplayVendorID] as? UInt32,
                   let productID = info?[kDisplayProductID] as? UInt32 {
                    // This is a simplified match; may need more sophisticated matching
                    servicePort = service
                    break
                }

                IOObjectRelease(service)
                service = IOIteratorNext(iter)
            }

            IOObjectRelease(iter)
        }

        return servicePort
    }

    // MARK: - Display Selection

    func selectDisplay(_ display: Display) {
        selectedDisplay = display

        if rememberDisplayPreference {
            saveSelectedDisplay()
        }
    }

    private func loadSelectedDisplay() {
        rememberDisplayPreference = UserDefaults.standard.object(forKey: "rememberDisplayPreference") as? Bool ?? true

        if rememberDisplayPreference,
           let displayID = UserDefaults.standard.string(forKey: selectedDisplayKey) {
            selectedDisplay = availableDisplays.first { $0.id == displayID }
        }

        // Fall back to primary display
        if selectedDisplay == nil {
            selectedDisplay = availableDisplays.first { $0.isPrimary }
        }
    }

    private func saveSelectedDisplay() {
        if let display = selectedDisplay {
            UserDefaults.standard.set(display.id, forKey: selectedDisplayKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedDisplayKey)
        }
    }

    // MARK: - Capture Options

    func getCaptureArguments(for display: Display, captureType: String) -> [String] {
        var args: [String] = []

        // Add display-specific argument
        args.append("-D")
        args.append(display.id)

        // Add capture type arguments
        switch captureType {
        case "selected_area":
            args.append("-i")
        case "window":
            args.append("-w")
        case "full_screen":
            // Full screen capture of the selected display
            break
        default:
            break
        }

        return args
    }

    // MARK: - Display Arrangement

    func getDisplayArrangement() -> String {
        guard availableDisplays.count > 1 else { return "Single Display" }

        // Analyze display positions
        let displays = availableDisplays.sorted { $0.position.x < $1.position.x }

        var arrangement = "Multiple Displays: "

        for (index, display) in displays.enumerated() {
            arrangement += display.name
            if index < displays.count - 1 {
                arrangement += " → "
            }
        }

        return arrangement
    }

    // MARK: - Display Information

    func getPrimaryDisplay() -> Display? {
        return availableDisplays.first { $0.isPrimary }
    }

    func getDisplayCount() -> Int {
        return availableDisplays.count
    }

    func getDisplay(byID id: String) -> Display? {
        return availableDisplays.first { $0.id == id }
    }

    // MARK: - Quick Select

    func selectPrimaryDisplay() {
        if let primary = getPrimaryDisplay() {
            selectDisplay(primary)
        }
    }

    func selectNextDisplay() {
        guard availableDisplays.count > 1,
              let current = selectedDisplay,
              let currentIndex = availableDisplays.firstIndex(of: current) else {
            return
        }

        let nextIndex = (currentIndex + 1) % availableDisplays.count
        selectDisplay(availableDisplays[nextIndex])
    }

    func selectPreviousDisplay() {
        guard availableDisplays.count > 1,
              let current = selectedDisplay,
              let currentIndex = availableDisplays.firstIndex(of: current) else {
            return
        }

        let previousIndex = (currentIndex - 1 + availableDisplays.count) % availableDisplays.count
        selectDisplay(availableDisplays[previousIndex])
    }
}
