import SwiftUI
import AppKit
import ScreenCaptureKit

/// Represents a selectable window
struct SelectableWindow: Identifiable {
    let id: CGWindowID
    let frame: CGRect
    let title: String
    let ownerName: String
    let layer: Int
    let windowRef: SCWindow
    
    var displayTitle: String {
        if title.isEmpty {
            return ownerName
        }
        return "\(ownerName) - \(title)"
    }
}

enum ScreenOption: String, CaseIterable, Identifiable {
    case selectedArea = "Selected Area"
    case window = "Window"
    case fullScreen = "Full Screen"
    case scrollingCapture = "Scrolling Capture"

    var id: String { self.rawValue }

    var displayName: String {
        self.rawValue
    }

    var icon: String {
        switch self {
        case .selectedArea:
            return "selection.pin.in.out"
        case .window:
            return "macwindow"
        case .fullScreen:
            return "display"
        case .scrollingCapture:
            return "scroll"
        }
    }
}

enum OpenOption: String, CaseIterable, Identifiable {
    case clipboard = "Clipboard"
    case saveToFile = "Save to File"
    case editor = "Editor"

    var id: String { self.rawValue }

    var displayName: String {
        self.rawValue
    }

    var icon: String {
        switch self {
        case .clipboard:
            return "doc.on.clipboard"
        case .saveToFile:
            return "square.and.arrow.down"
        case .editor:
            return "pencil.and.outline"
        }
    }
}

extension Notification.Name {
    static let screenshotCaptured = Notification.Name("screenshotCaptured")
    static let screenshotSavedToHistory = Notification.Name("screenshotSavedToHistory")
}
