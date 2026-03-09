//
//  CaptureType.swift
//  ScreenGrabber
//
//  Defines all capture types and their configurations
//

import Foundation

enum CaptureType: String, Codable, CaseIterable, Identifiable {
    case area
    case window
    case fullScreen
    case scrolling
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .area: return "Select Area"
        case .window: return "Window"
        case .fullScreen: return "Full Screen"
        case .scrolling: return "Scrolling Capture"
        }
    }
    
    var icon: String {
        switch self {
        case .area: return "rectangle.dashed"
        case .window: return "macwindow"
        case .fullScreen: return "display"
        case .scrolling: return "scroll"
        }
    }
    
    var description: String {
        switch self {
        case .area: return "Capture a selected area of the screen"
        case .window: return "Capture a specific window"
        case .fullScreen: return "Capture the entire screen"
        case .scrolling: return "Automatically scroll and capture tall content"
        }
    }
}

enum OpenMethod: String, Codable {
    case clipboard
    case saveToFile
    case preview
    case editor
    
    var displayName: String {
        switch self {
        case .clipboard: return "Copy to Clipboard"
        case .saveToFile: return "Save to File"
        case .preview: return "Quick Look"
        case .editor: return "Open in Editor"
        }
    }
}
