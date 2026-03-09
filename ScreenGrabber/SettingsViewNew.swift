//
//  SettingsViewNew.swift
//  ScreenGrabber
//
//  Color+Hex extensions used by EditorSettingsPane (SettingsWindow) and
//  the annotation color picker in the editor.
//
//  All settings view structs that were here have been consolidated into SettingsWindow.swift.
//

import SwiftUI

// MARK: - Color Hex Helpers

extension Color {
    /// Initialise a Color from a 6- or 8-character hex string (e.g. "FF0000", "FFFF0000").
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard Scanner(string: cleaned).scanHexInt64(&value) else { return nil }

        let a, r, g, b: UInt64
        switch cleaned.count {
        case 6: (a, r, g, b) = (255, value >> 16, value >> 8 & 0xFF, value & 0xFF)
        case 8: (a, r, g, b) = (value >> 24, value >> 16 & 0xFF, value >> 8 & 0xFF, value & 0xFF)
        default: return nil
        }

        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    /// Convert Color to a 6-character hex string ("RRGGBB").
    func toHex() -> String? {
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
