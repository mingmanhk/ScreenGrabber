//
//  ColorThemes.swift
//  ScreenGrabber
//
//  Color theme presets for easy customization
//  Created on 01/03/26.
//

import SwiftUI

// MARK: - Color Theme System

struct AppColors {
    static var current: ColorTheme = .classic
    
    // Easy theme switching
    enum ColorTheme {
        case classic      // Original red accent
        case blue         // Blue accent
        case purple       // Purple accent
        case orange       // Orange accent
        case green        // Green accent
        case professional // Muted professional colors
        case dark         // Dark mode optimized
    }
    
    // MARK: - Accent Colors
    
    static var accent: Color {
        switch current {
        case .classic:
            return Color(red: 1.0, green: 0.23, blue: 0.19) // #FF3B30
        case .blue:
            return Color(red: 0.0, green: 0.48, blue: 1.0) // #007AFF
        case .purple:
            return Color(red: 0.69, green: 0.32, blue: 0.87) // #AF52DE
        case .orange:
            return Color(red: 1.0, green: 0.58, blue: 0.0) // #FF9500
        case .green:
            return Color(red: 0.2, green: 0.78, blue: 0.35) // #34C759
        case .professional:
            return Color(red: 0.26, green: 0.46, blue: 0.75) // #4376BF
        case .dark:
            return Color(red: 1.0, green: 0.27, blue: 0.23) // Brighter red for dark mode
        }
    }
    
    static var accentGradient: LinearGradient {
        switch current {
        case .classic:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.23, blue: 0.19), Color(red: 1.0, green: 0.27, blue: 0.23)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .blue:
            return LinearGradient(
                colors: [Color(red: 0.0, green: 0.48, blue: 1.0), Color(red: 0.2, green: 0.6, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .purple:
            return LinearGradient(
                colors: [Color(red: 0.69, green: 0.32, blue: 0.87), Color(red: 0.75, green: 0.4, blue: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .orange:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.58, blue: 0.0), Color(red: 1.0, green: 0.65, blue: 0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .green:
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.78, blue: 0.35), Color(red: 0.25, green: 0.85, blue: 0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .professional:
            return LinearGradient(
                colors: [Color(red: 0.26, green: 0.46, blue: 0.75), Color(red: 0.3, green: 0.52, blue: 0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.27, blue: 0.23), Color(red: 0.9, green: 0.2, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - UI Colors
    
    static var panelBackground: Color {
        Color(NSColor.controlBackgroundColor).opacity(0.5)
    }
    
    static var hoverBorder: Color {
        accent
    }
    
    static var selectedBackground: Color {
        accent.opacity(0.1)
    }
    
    // MARK: - Quick Color Presets for Editor
    
    static let editorColors: [Color] = [
        .red,
        .blue,
        .green,
        Color(red: 1.0, green: 0.58, blue: 0.0), // Orange
        Color(red: 1.0, green: 0.8, blue: 0.0),  // Yellow
        Color(red: 0.69, green: 0.32, blue: 0.87), // Purple
        Color(red: 1.0, green: 0.18, blue: 0.33), // Pink
        .black
    ]
}

// MARK: - Layout Dimensions

struct AppLayout {
    // Window sizes
    static let minWindowWidth: CGFloat = 1200
    static let minWindowHeight: CGFloat = 700
    static let recommendedWindowWidth: CGFloat = 1400
    static let recommendedWindowHeight: CGFloat = 900
    
    // Panel sizes
    static var sidePanelWidth: CGFloat = 280  // Adjustable
    static let topToolbarHeight: CGFloat = 52
    static let bottomStripHeight: CGFloat = 100
    
    // Thumbnail sizes
    static var gridThumbnailWidth: CGFloat = 200
    static var gridThumbnailHeight: CGFloat = 150
    static var stripThumbnailWidth: CGFloat = 100
    static var stripThumbnailHeight: CGFloat = 70
    
    // Spacing
    static let basePadding: CGFloat = 20
    static let gridSpacing: CGFloat = 20
    static let componentSpacing: CGFloat = 12
    static let tightSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 20
    
    // Button sizes
    static let smallButtonSize: CGFloat = 28
    static let mediumButtonSize: CGFloat = 32
    static let largeButtonSize: CGFloat = 44
    
    // Corner radius
    static let buttonCornerRadius: CGFloat = 8
    static let thumbnailCornerRadius: CGFloat = 8
    static let panelCornerRadius: CGFloat = 12
}

// MARK: - Typography

struct AppTypography {
    // Fonts
    static let appTitle = Font.system(size: 16, weight: .bold)
    static let panelTitle = Font.system(size: 18, weight: .bold)
    static let sectionTitle = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 14, weight: .medium)
    static let bodyLarge = Font.system(size: 15, weight: .medium)
    static let buttonText = Font.system(size: 15, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .medium)
    static let smallCaption = Font.system(size: 11, weight: .medium)
    static let tinyText = Font.system(size: 10, weight: .medium)
    
    // Icon sizes
    static let smallIcon = Font.system(size: 12, weight: .medium)
    static let mediumIcon = Font.system(size: 14, weight: .medium)
    static let largeIcon = Font.system(size: 16, weight: .semibold)
    static let hugeIcon = Font.system(size: 60, weight: .light)
}

// MARK: - Animation Timings

struct AppAnimations {
    static let fast: Double = 0.15
    static let standard: Double = 0.2
    static let slow: Double = 0.3
    static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let easeInOut = Animation.easeInOut(duration: standard)
}

// MARK: - Preset Configurations

extension AppColors {
    /// Apply a theme to the entire app
    static func applyTheme(_ theme: ColorTheme) {
        current = theme
    }
}

extension AppLayout {
    /// Preset: Compact layout (for smaller screens)
    static func applyCompact() {
        sidePanelWidth = 240
        gridThumbnailWidth = 180
        gridThumbnailHeight = 135
        stripThumbnailWidth = 90
        stripThumbnailHeight = 63
    }
    
    /// Preset: Normal layout (default)
    static func applyNormal() {
        sidePanelWidth = 280
        gridThumbnailWidth = 200
        gridThumbnailHeight = 150
        stripThumbnailWidth = 100
        stripThumbnailHeight = 70
    }
    
    /// Preset: Spacious layout (for larger screens)
    static func applySpacious() {
        sidePanelWidth = 320
        gridThumbnailWidth = 240
        gridThumbnailHeight = 180
        stripThumbnailWidth = 120
        stripThumbnailHeight = 90
    }
}

// MARK: - Usage Examples

/*
 
 # How to Use Custom Themes
 
 ## 1. Change App Color Theme
 
 In your app initialization or settings:
 
 ```swift
 // In ScreenGrabberApp.swift or ContentView
 AppColors.applyTheme(.blue)  // Changes to blue theme
 ```
 
 ## 2. Use Theme Colors in Components
 
 Instead of hardcoded colors:
 
 ```swift
 // Before:
 .foregroundColor(.red)
 
 // After:
 .foregroundColor(AppColors.accent)
 ```
 
 ## 3. Apply Layout Presets
 
 ```swift
 // In ContentView.onAppear
 AppLayout.applyCompact()  // For smaller screens
 AppLayout.applySpacious() // For large displays
 ```
 
 ## 4. Use Consistent Typography
 
 ```swift
 Text("Panel Title")
     .font(AppTypography.panelTitle)
 
 Text("Section")
     .font(AppTypography.sectionTitle)
 ```
 
 ## 5. Consistent Animations
 
 ```swift
 .animation(AppAnimations.easeInOut, value: isHovered)
 ```
 
 # Quick Theme Switching
 
 Add this to your settings panel:
 
 ```swift
 Picker("Theme", selection: $selectedTheme) {
     Text("Classic Red").tag(AppColors.ColorTheme.classic)
     Text("Blue").tag(AppColors.ColorTheme.blue)
     Text("Purple").tag(AppColors.ColorTheme.purple)
     Text("Orange").tag(AppColors.ColorTheme.orange)
     Text("Green").tag(AppColors.ColorTheme.green)
     Text("Professional").tag(AppColors.ColorTheme.professional)
 }
 .onChange(of: selectedTheme) { _, newValue in
     AppColors.applyTheme(newValue)
 }
 ```
 
 # Layout Size Options
 
 ```swift
 Picker("Layout", selection: $layoutSize) {
     Text("Compact").tag(0)
     Text("Normal").tag(1)
     Text("Spacious").tag(2)
 }
 .onChange(of: layoutSize) { _, newValue in
     switch newValue {
     case 0: AppLayout.applyCompact()
     case 1: AppLayout.applyNormal()
     case 2: AppLayout.applySpacious()
     default: break
     }
 }
 ```
 
 */
