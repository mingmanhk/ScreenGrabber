//
//  SharedViewStyles.swift
//  ScreenGrabber
//
//  Shared button styles, design tokens, and reusable UI components.
//

import SwiftUI
import AppKit

// MARK: - Design Tokens

/// Single source of truth for spacing, typography, and corner radii.
/// Use these constants instead of magic numbers throughout the UI.
enum DesignTokens {
    // Spacing
    static let spacingXS:  CGFloat = 4
    static let spacingSM:  CGFloat = 8
    static let spacingMD:  CGFloat = 12
    static let spacingLG:  CGFloat = 16
    static let spacingXL:  CGFloat = 20
    static let spacingXXL: CGFloat = 24

    // Corner radii
    static let radiusSM: CGFloat = 6
    static let radiusMD: CGFloat = 8
    static let radiusLG: CGFloat = 10

    // Font sizes
    static let fontCaption:    CGFloat = 10
    static let fontSmall:      CGFloat = 12
    static let fontBody:       CGFloat = 13
    static let fontSubhead:    CGFloat = 14
    static let fontHeadline:   CGFloat = 17
    static let fontTitle:      CGFloat = 20

    // Opacity
    static let dimBackground:  Double = 0.08
    static let dimBorder:      Double = 0.12
    static let dimShadow:      Double = 0.20
}

// MARK: - Semantic Font Scale

extension Font {
    static let sgCaption:  Font = .system(size: DesignTokens.fontCaption)
    static let sgSmall:    Font = .system(size: DesignTokens.fontSmall)
    static let sgBody:     Font = .system(size: DesignTokens.fontBody)
    static let sgSubhead:  Font = .system(size: DesignTokens.fontSubhead, weight: .medium)
    static let sgHeadline: Font = .system(size: DesignTokens.fontHeadline, weight: .bold)
    static let sgTitle:    Font = .system(size: DesignTokens.fontTitle, weight: .bold)
}

// MARK: - Button Styles

/// Scale button style with spring animation
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Reusable Components

/// Custom option button for capture and output methods
struct OptionButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(height: 20)
                
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor))
                        
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                }
            )
            .shadow(
                color: isSelected ? Color.blue.opacity(0.4) : Color.clear,
                radius: isSelected ? 8 : 0,
                x: 0,
                y: isSelected ? 4 : 0
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

/// Custom action button for footer menu actions
struct MenuActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            isHovered
                                ? color.opacity(0.15)
                                : Color(NSColor.controlBackgroundColor)
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(
                            isHovered
                                ? color
                                : .secondary
                        )
                }
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(
                        isHovered
                            ? color.opacity(0.9)
                            : .secondary
                    )
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
/// Dropdown section with expandable menu
struct DropdownSection<Content: View>: View {
    let title: String
    let icon: String
    let selectedText: String
    @ViewBuilder let content: () -> Content
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 20)
            
            // Dropdown Button
            Menu {
                content()
            } label: {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: 20)
                    
                    Text(selectedText)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
        }
    }
}

/// Toggle option with icon
struct ToggleOption: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 20)
    }
}

