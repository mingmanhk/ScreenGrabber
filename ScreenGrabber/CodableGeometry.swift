//
//  CodableGeometry.swift
//  ScreenGrabber
//
//  Codable wrappers for geometric types
//

import Foundation
import CoreGraphics
import AppKit

// MARK: - Codable Point
struct CodablePoint: Hashable, Sendable {
    var x: Double
    var y: Double
    
    init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

// CGPoint conversion in separate extension
extension CodablePoint {
    init(_ point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }
    
    // Compatibility initializer
    init(point: CGPoint) {
        self.x = Double(point.x)
        self.y = Double(point.y)
    }
    
    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }
}

// Explicit Codable conformance in nonisolated context for SwiftData
extension CodablePoint: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.x = try container.decode(Double.self, forKey: .x)
        self.y = try container.decode(Double.self, forKey: .y)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}

// MARK: - Codable Rect
struct CodableRect: Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    
    init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// CGRect conversion in separate extension
extension CodableRect {
    init(_ rect: CGRect) {
        self.x = Double(rect.origin.x)
        self.y = Double(rect.origin.y)
        self.width = Double(rect.size.width)
        self.height = Double(rect.size.height)
    }
    
    // Compatibility initializer
    init(rect: CGRect) {
        self.x = Double(rect.origin.x)
        self.y = Double(rect.origin.y)
        self.width = Double(rect.size.width)
        self.height = Double(rect.size.height)
    }
    
    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

// Explicit Codable conformance in nonisolated context for SwiftData
extension CodableRect: Codable {
    enum CodingKeys: String, CodingKey {
        case x, y, width, height
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.x = try container.decode(Double.self, forKey: .x)
        self.y = try container.decode(Double.self, forKey: .y)
        self.width = try container.decode(Double.self, forKey: .width)
        self.height = try container.decode(Double.self, forKey: .height)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}

// MARK: - Codable Size
struct CodableSize: Hashable, Sendable {
    var width: Double
    var height: Double
    
    init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

// CGSize conversion in separate extension
extension CodableSize {
    init(_ size: CGSize) {
        self.width = Double(size.width)
        self.height = Double(size.height)
    }
    
    var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}

// Explicit Codable conformance in nonisolated context for SwiftData
extension CodableSize: Codable {
    enum CodingKeys: String, CodingKey {
        case width, height
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.width = try container.decode(Double.self, forKey: .width)
        self.height = try container.decode(Double.self, forKey: .height)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}

// MARK: - Codable Color
struct CodableColor: Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    
    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

// Explicit Codable conformance MUST come before MainActor extensions
// to avoid actor isolation inference in Swift 6
extension CodableColor: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.red = try container.decode(Double.self, forKey: .red)
        self.green = try container.decode(Double.self, forKey: .green)
        self.blue = try container.decode(Double.self, forKey: .blue)
        self.alpha = try container.decode(Double.self, forKey: .alpha)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(red, forKey: .red)
        try container.encode(green, forKey: .green)
        try container.encode(blue, forKey: .blue)
        try container.encode(alpha, forKey: .alpha)
    }
}

// NSColor conversion in separate extension isolated to MainActor
extension CodableColor {
    @MainActor
    init(_ nsColor: NSColor) {
        // Convert to RGB color space and call memberwise init
        guard let rgbColor = nsColor.usingColorSpace(.deviceRGB) else {
            self.init(red: 0, green: 0, blue: 0, alpha: 1)
            return
        }
        
        self.init(
            red: Double(rgbColor.redComponent),
            green: Double(rgbColor.greenComponent),
            blue: Double(rgbColor.blueComponent),
            alpha: Double(rgbColor.alphaComponent)
        )
    }
    
    // Compatibility initializer
    @MainActor
    init(color: NSColor) {
        self.init(color)
    }
    
    @MainActor
    var nsColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }
}


