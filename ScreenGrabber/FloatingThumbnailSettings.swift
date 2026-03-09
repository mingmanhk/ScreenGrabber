//
//  FloatingThumbnailSettings.swift
//  ScreenGrabber
//
//  Settings for floating thumbnail behavior
//

import Foundation
import SwiftUI

/// Configuration for floating thumbnail preview after capture
struct FloatingThumbnailSettings: Codable, Equatable {
    var enabled: Bool
    var duration: TimeInterval
    var position: ThumbnailPosition
    var size: CGSize
    var fadeOutDuration: TimeInterval
    
    enum ThumbnailPosition: String, Codable, CaseIterable {
        case bottomRight
        case bottomLeft
        case topRight
        case topLeft
        
        var displayName: String {
            switch self {
            case .bottomRight: return "Bottom Right"
            case .bottomLeft: return "Bottom Left"
            case .topRight: return "Top Right"
            case .topLeft: return "Top Left"
            }
        }
    }
    
    static let `default` = FloatingThumbnailSettings(
        enabled: true,
        duration: 3.0,
        position: .bottomRight,
        size: CGSize(width: 200, height: 150),
        fadeOutDuration: 0.3
    )
}
