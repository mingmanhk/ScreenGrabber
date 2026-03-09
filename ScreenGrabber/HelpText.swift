//
//  HelpText.swift
//  ScreenGrabber
//
//  Created on 01/17/26.
//  Help text and guidance for complex features
//

import SwiftUI

// MARK: - Help Content Model

struct HelpContent: Identifiable {
    let id = UUID()
    let title: String
    let sections: [HelpSection]
    
    struct HelpSection {
        let heading: String
        let content: [HelpItem]
    }
    
    enum HelpItem {
        case text(String)
        case list([String])
        case tip(String)
        case warning(String)
        case image(String) // SF Symbol name
        case steps([String])
    }
}

// MARK: - Predefined Help Content

extension HelpContent {
    // MARK: - Scrolling Capture Help
    
    static let scrollingCapture = HelpContent(
        title: "Scrolling Capture",
        sections: [
            HelpSection(
                heading: "What is Scrolling Capture?",
                content: [
                    .text("Scrolling capture automatically captures the entire content of a scrollable window, including the parts you can't see on screen. It's perfect for capturing long web pages, documents, or chat conversations."),
                    .image("arrow.down.doc.fill")
                ]
            ),
            HelpSection(
                heading: "How to Use",
                content: [
                    .steps([
                        "Start a capture (⌘⇧5)",
                        "Click \"Start Scrolling Capture\"",
                        "Select the window you want to capture",
                        "Screen Grabber will automatically scroll and capture the entire content",
                        "Review and edit your capture when it's complete"
                    ])
                ]
            ),
            HelpSection(
                heading: "Tips",
                content: [
                    .tip("Works best with web pages, documents, and lists"),
                    .tip("Make sure the window is scrollable before starting"),
                    .tip("You can cancel at any time by pressing Esc")
                ]
            ),
            HelpSection(
                heading: "Limitations",
                content: [
                    .warning("Scrolling capture requires Screen Recording permission"),
                    .text("Some apps may not support automatic scrolling. In these cases, you'll need to capture manually."),
                    .text("Very long pages may take a moment to capture. Please be patient!")
                ]
            )
        ]
    )
    
    // MARK: - Window Selection Help
    
    static let windowSelection = HelpContent(
        title: "Window Selection",
        sections: [
            HelpSection(
                heading: "Selecting Windows",
                content: [
                    .text("Window selection lets you capture a specific window or screen element with precision."),
                    .image("macwindow")
                ]
            ),
            HelpSection(
                heading: "Selection Modes",
                content: [
                    .text("**Area Selection**: Drag to select any rectangular area"),
                    .text("**Window Selection**: Click a window to capture it with or without its shadow"),
                    .tip("Press Space to toggle between area and window selection modes")
                ]
            ),
            HelpSection(
                heading: "Keyboard Shortcuts",
                content: [
                    .list([
                        "Space – Toggle selection mode",
                        "Esc – Cancel capture",
                        "Return – Confirm capture",
                        "⌘ – Hold to capture without shadow"
                    ])
                ]
            ),
            HelpSection(
                heading: "Tips",
                content: [
                    .tip("Hover over a window to see it highlighted"),
                    .tip("Use ⌘ to capture windows without their shadow"),
                    .tip("Click menu bar items to capture dropdown menus")
                ]
            )
        ]
    )
    
    // MARK: - Annotation Tools Help
    
    static let annotationTools = HelpContent(
        title: "Annotation Tools",
        sections: [
            HelpSection(
                heading: "Available Tools",
                content: [
                    .text("Screen Grabber provides powerful annotation tools to mark up your screenshots:"),
                    .list([
                        "**Arrow (A)** – Point out important elements",
                        "**Pen (P)** – Draw freehand annotations",
                        "**Text (T)** – Add text labels and descriptions",
                        "**Shape (S)** – Add rectangles, circles, and lines",
                        "**Highlight (H)** – Emphasize areas with semi-transparent color",
                        "**Pixelate (X)** – Blur or pixelate sensitive information"
                    ])
                ]
            ),
            HelpSection(
                heading: "Using the Tools",
                content: [
                    .steps([
                        "Select a tool from the toolbar or press its keyboard shortcut",
                        "Click and drag on your screenshot to create the annotation",
                        "Adjust colors, sizes, and styles in the toolbar",
                        "Use ⌘Z to undo or ⌘⇧Z to redo"
                    ])
                ]
            ),
            HelpSection(
                heading: "Editing Annotations",
                content: [
                    .text("Click any annotation to select it, then:"),
                    .list([
                        "Drag to reposition",
                        "Drag handles to resize",
                        "Press Delete to remove",
                        "Change colors and styles in the toolbar"
                    ]),
                    .tip("Hold Shift while dragging to constrain movement to horizontal or vertical")
                ]
            ),
            HelpSection(
                heading: "Keyboard Shortcuts",
                content: [
                    .list([
                        "A – Arrow tool",
                        "P – Pen tool",
                        "T – Text tool",
                        "S – Shape tool",
                        "H – Highlight tool",
                        "X – Pixelate tool",
                        "⌘Z – Undo",
                        "⌘⇧Z – Redo",
                        "⌫ – Delete selected annotation"
                    ])
                ]
            )
        ]
    )
    
    // MARK: - Save Location Help
    
    static let saveLocation = HelpContent(
        title: "Save Location",
        sections: [
            HelpSection(
                heading: "Where Are Screenshots Saved?",
                content: [
                    .text("By default, Screen Grabber saves screenshots to:"),
                    .text("**~/Pictures/Screen Grabber/**"),
                    .text("You can change this location in Settings → Capture.")
                ]
            ),
            HelpSection(
                heading: "Choosing a Custom Location",
                content: [
                    .steps([
                        "Open Settings (⌘,)",
                        "Go to the Capture tab",
                        "Click \"Choose Folder…\" under Save Location",
                        "Select your preferred folder",
                        "Click \"Select\" to confirm"
                    ]),
                    .tip("Choose a folder that's accessible and has enough free space")
                ]
            ),
            HelpSection(
                heading: "Folder Permissions",
                content: [
                    .text("Screen Grabber needs permission to save files to your chosen folder. If you see permission errors:"),
                    .list([
                        "Ensure the folder exists and is accessible",
                        "Check folder permissions in Finder",
                        "Try selecting a different folder",
                        "Restart Screen Grabber after changing permissions"
                    ]),
                    .warning("Some system folders may require additional permissions")
                ]
            ),
            HelpSection(
                heading: "File Naming",
                content: [
                    .text("Screenshots are automatically named with the format:"),
                    .text("**Screenshot YYYY-MM-DD at HH.MM.SS.png**"),
                    .tip("You can rename files immediately after saving in Finder")
                ]
            )
        ]
    )
}

// MARK: - Help View

/// Displays help content in a clean, readable format
struct HelpView: View {
    let content: HelpContent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(content.title)
                    .font(.title2.bold())
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(content.sections, id: \.heading) { section in
                        VStack(alignment: .leading, spacing: 12) {
                            // Section heading
                            Text(section.heading)
                                .font(.headline)
                            
                            // Section content
                            ForEach(Array(section.content.enumerated()), id: \.offset) { _, item in
                                HelpItemView(item: item)
                            }
                        }
                    }
                }
                .padding(20)
            }
            
            // Footer
            Divider()
            
            HStack {
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 600, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Help Item View

struct HelpItemView: View {
    let item: HelpContent.HelpItem
    
    var body: some View {
        switch item {
        case .text(let text):
            Text(text)
                .font(.body)
                .foregroundStyle(.primary)
            
        case .list(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.body)
                        Text(item)
                            .font(.body)
                    }
                }
            }
            
        case .tip(let text):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.body)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
        case .warning(let text):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.body)
                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
        case .image(let systemName):
            Image(systemName: systemName)
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            
        case .steps(let steps):
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        // Step number
                        Text("\(index + 1)")
                            .font(.body.bold())
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Color.accentColor))
                        
                        // Step text
                        Text(step)
                            .font(.body)
                    }
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Help Button

/// A standard help button that shows help content
struct HelpButton: View {
    let content: HelpContent
    @State private var isShowingHelp = false
    
    var body: some View {
        Button {
            isShowingHelp = true
        } label: {
            Image(systemName: "questionmark.circle")
        }
        .buttonStyle(.plain)
        .help("Show help for \(content.title)")
        .popover(isPresented: $isShowingHelp) {
            HelpView(content: content)
        }
    }
}

// MARK: - Inline Help Text

/// Shows help text inline without requiring a popover
struct InlineHelpText: View {
    let text: String
    let icon: String
    
    init(_ text: String, icon: String = "info.circle") {
        self.text = text
        self.icon = icon
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.body)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Improved Dialogs

/// A custom alert with action-oriented buttons
struct ActionAlert {
    let title: String
    let message: String
    let icon: String?
    let style: NSAlert.Style
    let primaryButton: AlertButton
    let secondaryButton: AlertButton?
    let tertiaryButton: AlertButton?
    
    struct AlertButton {
        let title: String
        let action: () -> Void
        let isDefault: Bool
        
        init(title: String, isDefault: Bool = false, action: @escaping () -> Void = {}) {
            self.title = title
            self.isDefault = isDefault
            self.action = action
        }
    }
    
    init(
        title: String,
        message: String,
        icon: String? = nil,
        style: NSAlert.Style = .informational,
        primaryButton: AlertButton,
        secondaryButton: AlertButton? = nil,
        tertiaryButton: AlertButton? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.style = style
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.tertiaryButton = tertiaryButton
    }
    
    @MainActor
    func show() {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        
        // Add buttons
        alert.addButton(withTitle: primaryButton.title)
        if let secondary = secondaryButton {
            alert.addButton(withTitle: secondary.title)
        }
        if let tertiary = tertiaryButton {
            alert.addButton(withTitle: tertiary.title)
        }
        
        // Add icon if provided
        if let iconName = icon {
            let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            alert.icon = image
        }
        
        let response = alert.runModal()
        
        switch response {
        case .alertFirstButtonReturn:
            primaryButton.action()
        case .alertSecondButtonReturn:
            secondaryButton?.action()
        case .alertThirdButtonReturn:
            tertiaryButton?.action()
        default:
            break
        }
    }
}

// MARK: - Common Dialogs

extension ActionAlert {
    /// Confirm deletion with action-oriented buttons
    static func confirmDeletion(
        itemName: String,
        onDelete: @escaping () -> Void
    ) -> ActionAlert {
        ActionAlert(
            title: "Delete \"\(itemName)\"?",
            message: "This action cannot be undone.",
            icon: "trash",
            style: .warning,
            primaryButton: .init(title: "Delete", isDefault: false, action: onDelete),
            secondaryButton: .init(title: "Cancel", isDefault: true)
        )
    }
    
    /// Confirm saving changes
    static func confirmSaveChanges(
        documentName: String,
        onSave: @escaping () -> Void,
        onDiscard: @escaping () -> Void
    ) -> ActionAlert {
        ActionAlert(
            title: "Do you want to save changes to \"\(documentName)\"?",
            message: "Your changes will be lost if you don't save them.",
            icon: "exclamationmark.triangle",
            style: .warning,
            primaryButton: .init(title: "Save", isDefault: true, action: onSave),
            secondaryButton: .init(title: "Don't Save", action: onDiscard),
            tertiaryButton: .init(title: "Cancel")
        )
    }
    
    /// Show permission error
    static func permissionRequired(
        permission: String,
        reason: String,
        onOpenSettings: @escaping () -> Void
    ) -> ActionAlert {
        ActionAlert(
            title: "\(permission) Permission Required",
            message: reason,
            icon: "lock.shield",
            style: .warning,
            primaryButton: .init(title: "Open System Settings", isDefault: true, action: onOpenSettings),
            secondaryButton: .init(title: "Cancel")
        )
    }
    
    /// Show save error
    static func saveError(
        path: String,
        error: String,
        onRetry: @escaping () -> Void,
        onChooseDifferent: @escaping () -> Void
    ) -> ActionAlert {
        ActionAlert(
            title: "Unable to Save File",
            message: "Screen Grabber doesn't have permission to save files to \"\(path)\". \(error)",
            icon: "exclamationmark.triangle",
            style: .critical,
            primaryButton: .init(title: "Choose Different Location", isDefault: true, action: onChooseDifferent),
            secondaryButton: .init(title: "Retry", action: onRetry),
            tertiaryButton: .init(title: "Cancel")
        )
    }
    
    /// Confirm file overwrite
    static func confirmOverwrite(
        filename: String,
        onOverwrite: @escaping () -> Void
    ) -> ActionAlert {
        ActionAlert(
            title: "\"\(filename)\" already exists.",
            message: "Do you want to replace it?",
            icon: "doc.badge.exclamationmark",
            style: .warning,
            primaryButton: .init(title: "Replace", isDefault: false, action: onOverwrite),
            secondaryButton: .init(title: "Cancel", isDefault: true)
        )
    }
}

// MARK: - Previews

#Preview("Help View") {
    HelpView(content: .scrollingCapture)
}

#Preview("Annotation Help") {
    HelpView(content: .annotationTools)
}

#Preview("Window Selection Help") {
    HelpView(content: .windowSelection)
}

#Preview("Save Location Help") {
    HelpView(content: .saveLocation)
}

#Preview("Inline Help") {
    VStack(spacing: 16) {
        InlineHelpText("This is a helpful tip about how to use this feature effectively.")
        InlineHelpText("Warning: This action cannot be undone.", icon: "exclamationmark.triangle")
        InlineHelpText("Tip: Press Space to toggle modes.", icon: "lightbulb")
    }
    .padding()
}
