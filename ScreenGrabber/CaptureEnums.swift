//
//  CaptureEnums.swift
//  ScreenGrabber
//
//  Created on 01/04/26.
//  Centralized enums for capture settings
//

import Foundation

// MARK: - Capture Effects
enum CaptureEffect: String, CaseIterable, Identifiable {
    case none = "None"
    case shadow = "Shadow"
    case border = "Border"
    case glow = "Glow"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .none: return "slash.circle"
        case .shadow: return "shadow"
        case .border: return "square.dashed"
        case .glow: return "sun.max"
        }
    }
    
    var description: String {
        switch self {
        case .none: return "No effect applied"
        case .shadow: return "Add drop shadow"
        case .border: return "Add border outline"
        case .glow: return "Add glow effect"
        }
    }
}

// MARK: - Share Options
enum ShareOption: String, CaseIterable, Identifiable {
    case none = "None"
    case email = "Email"
    case messages = "Messages"
    case airdrop = "AirDrop"
    case cloud = "iCloud"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .none: return "slash.circle"
        case .email: return "envelope"
        case .messages: return "message"
        case .airdrop: return "airplayaudio"
        case .cloud: return "icloud"
        }
    }
    
    var description: String {
        switch self {
        case .none: return "No sharing"
        case .email: return "Share via email"
        case .messages: return "Share via Messages"
        case .airdrop: return "Share via AirDrop"
        case .cloud: return "Upload to iCloud"
        }
    }
}

// MARK: - Capture Methods
enum CaptureMethod: String, CaseIterable, Identifiable {
    case area = "Area Selection"
    case window = "Window"
    case fullScreen = "Full Screen"
    case scrolling = "Scrolling Window"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .area: return "viewfinder.rectangular"
        case .window: return "macwindow"
        case .fullScreen: return "display"
        case .scrolling: return "scroll"
        }
    }
    
    var description: String {
        switch self {
        case .area: return "Drag to select an area"
        case .window: return "Capture a single window"
        case .fullScreen: return "Capture entire screen"
        case .scrolling: return "Capture scrollable content"
        }
    }
}

// MARK: - Editor Tools
// Note: The main EditorTool enum is defined in ImageEditorModels.swift
// This simplified version is kept for basic UI needs only
// Use ImageEditorModels.EditorTool for full editor functionality

// MARK: - Quick Styles
enum QuickStyle: String, CaseIterable, Identifiable {
    case arrow = "Arrow"
    case box = "Box"
    case circle = "Circle"
    case line = "Line"
    case highlight = "Highlight"
    case blur = "Blur"
    case text = "Text"
    case number = "Number"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .arrow: return "arrow.right"
        case .box: return "rectangle"
        case .circle: return "circle"
        case .line: return "line.diagonal"
        case .highlight: return "highlighter"
        case .blur: return "aqi.medium"
        case .text: return "textformat"
        case .number: return "number.circle"
        }
    }
}
