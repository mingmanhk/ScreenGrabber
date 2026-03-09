//
//  ContextualTips.swift
//  ScreenGrabber
//
//  Created on 01/17/26.
//  Contextual tips and hints that appear during use
//

import SwiftUI

// MARK: - Tip Model

/// A contextual tip that can be shown to users
struct ContextualTip: Identifiable, Equatable {
    let id: String
    let title: String
    let message: String
    let icon: String
    let category: Category
    
    enum Category {
        case capture
        case editing
        case shortcuts
        case productivity
    }
    
    static func == (lhs: ContextualTip, rhs: ContextualTip) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Tips Manager

@MainActor
@Observable
final class TipsManager {
    static let shared = TipsManager()
    
    // MARK: - State
    var currentTip: ContextualTip?
    var dismissedTips: Set<String> = []
    var tipsEnabled: Bool = true
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let dismissedTips = "tips.dismissed"
        static let tipsEnabled = "tips.enabled"
    }
    
    init() {
        loadDismissedTips()
        loadTipsEnabled()
    }
    
    // MARK: - Show/Dismiss
    
    /// Show a contextual tip if it hasn't been dismissed
    func showTip(_ tip: ContextualTip) {
        guard tipsEnabled else { return }
        guard !dismissedTips.contains(tip.id) else { return }
        
        currentTip = tip
    }
    
    /// Dismiss the current tip
    func dismissCurrentTip(permanently: Bool = false) {
        if permanently, let tip = currentTip {
            dismissedTips.insert(tip.id)
            saveDismissedTips()
        }
        currentTip = nil
    }
    
    /// Reset all dismissed tips
    func resetDismissedTips() {
        dismissedTips.removeAll()
        saveDismissedTips()
    }
    
    // MARK: - Persistence
    
    private func loadDismissedTips() {
        if let data = UserDefaults.standard.array(forKey: Keys.dismissedTips) as? [String] {
            dismissedTips = Set(data)
        }
    }
    
    private func saveDismissedTips() {
        UserDefaults.standard.set(Array(dismissedTips), forKey: Keys.dismissedTips)
    }
    
    private func loadTipsEnabled() {
        if UserDefaults.standard.object(forKey: Keys.tipsEnabled) == nil {
            tipsEnabled = true // Default to enabled
        } else {
            tipsEnabled = UserDefaults.standard.bool(forKey: Keys.tipsEnabled)
        }
    }
    
    func setTipsEnabled(_ enabled: Bool) {
        tipsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.tipsEnabled)
    }
}

// MARK: - Predefined Tips

extension ContextualTip {
    // MARK: - Capture Tips
    
    static let switchSelectionMode = ContextualTip(
        id: "switchSelectionMode",
        title: "Switch Selection Mode",
        message: "Press Space to toggle between area and window selection",
        icon: "keyboard",
        category: .shortcuts
    )
    
    static let scrollingCapture = ContextualTip(
        id: "scrollingCapture",
        title: "Capture Long Pages",
        message: "Use scrolling capture to capture entire web pages or documents automatically",
        icon: "arrow.down.doc",
        category: .capture
    )
    
    static let quickCapture = ContextualTip(
        id: "quickCapture",
        title: "Quick Capture",
        message: "Press ⌘⇧5 anytime to start a capture without opening the menu",
        icon: "command",
        category: .shortcuts
    )
    
    static let cancelCapture = ContextualTip(
        id: "cancelCapture",
        title: "Cancel Capture",
        message: "Press Esc to cancel the current capture operation",
        icon: "escape",
        category: .shortcuts
    )
    
    // MARK: - Editing Tips
    
    static let annotationShortcuts = ContextualTip(
        id: "annotationShortcuts",
        title: "Tool Shortcuts",
        message: "Use A for Arrow, P for Pen, T for Text, S for Shape, and H for Highlight",
        icon: "keyboard",
        category: .editing
    )
    
    static let undoRedo = ContextualTip(
        id: "undoRedo",
        title: "Undo & Redo",
        message: "Press ⌘Z to undo and ⌘⇧Z to redo your edits",
        icon: "arrow.uturn.backward",
        category: .editing
    )
    
    static let copyPaste = ContextualTip(
        id: "copyPaste",
        title: "Quick Copy",
        message: "Press ⌘C to copy your screenshot to the clipboard instantly",
        icon: "doc.on.clipboard",
        category: .productivity
    )
    
    // MARK: - Productivity Tips
    
    static let multipleCaptures = ContextualTip(
        id: "multipleCaptures",
        title: "Multiple Captures",
        message: "After saving, start another capture immediately with ⌘N",
        icon: "plus.rectangle.on.rectangle",
        category: .productivity
    )
    
    static let menuBarAccess = ContextualTip(
        id: "menuBarAccess",
        title: "Menu Bar Access",
        message: "Click the Screen Grabber icon in your menu bar for quick access to all features",
        icon: "menubar.rectangle",
        category: .productivity
    )
    
    static let allTips: [ContextualTip] = [
        .switchSelectionMode,
        .scrollingCapture,
        .quickCapture,
        .cancelCapture,
        .annotationShortcuts,
        .undoRedo,
        .copyPaste,
        .multipleCaptures,
        .menuBarAccess
    ]
}

// MARK: - Tip View

/// Display a contextual tip as an overlay
struct ContextualTipView: View {
    let tip: ContextualTip
    let onDismiss: (Bool) -> Void // Bool indicates if it should be permanently dismissed
    
    @State private var isVisible = false
    @State private var offset: CGFloat = 20
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(alignment: .top, spacing: 12) {
                // Icon
                Image(systemName: tip.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(.headline)
                    Text(tip.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Buttons
                VStack(spacing: 8) {
                    Button {
                        dismissWithAnimation(permanently: true)
                    } label: {
                        Text("Got It")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button {
                        dismissWithAnimation(permanently: false)
                    } label: {
                        Text("Remind Later")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .offset(y: offset)
            .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                offset = 0
                isVisible = true
            }
        }
    }
    
    private func dismissWithAnimation(permanently: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            offset = 20
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss(permanently)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds contextual tip overlay to any view
    func contextualTip() -> some View {
        ZStack(alignment: .bottom) {
            self
            
            if let tip = TipsManager.shared.currentTip {
                ContextualTipView(tip: tip) { permanently in
                    TipsManager.shared.dismissCurrentTip(permanently: permanently)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(999)
            }
        }
        .animation(.spring(), value: TipsManager.shared.currentTip)
    }
}

// MARK: - Keyboard Shortcuts Guide

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let shortcuts = ShortcutCategory.allCategories
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Keyboard Shortcuts")
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
                    ForEach(shortcuts) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            // Category header
                            HStack(spacing: 8) {
                                Image(systemName: category.icon)
                                    .foregroundStyle(category.color)
                                Text(category.name)
                                    .font(.headline)
                            }
                            
                            // Shortcuts
                            VStack(spacing: 8) {
                                ForEach(category.shortcuts) { shortcut in
                                    ShortcutRow(shortcut: shortcut)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            
            // Footer
            Divider()
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Customize shortcuts in System Settings → Keyboard → Shortcuts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 500, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Shortcut Models

struct ShortcutCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let shortcuts: [ShortcutInfo]
    
    static let allCategories: [ShortcutCategory] = [
        ShortcutCategory(
            name: "Capture",
            icon: "camera",
            color: .blue,
            shortcuts: [
                .init(name: "Quick Capture", keys: ["⌘", "⇧", "5"]),
                .init(name: "Area Capture", keys: ["⌘", "⇧", "4"]),
                .init(name: "Window Capture", keys: ["⌘", "⇧", "3"]),
                .init(name: "Cancel Capture", keys: ["Esc"]),
                .init(name: "Toggle Selection Mode", keys: ["Space"])
            ]
        ),
        ShortcutCategory(
            name: "Editing",
            icon: "pencil.tip.crop.circle",
            color: .orange,
            shortcuts: [
                .init(name: "Arrow Tool", keys: ["A"]),
                .init(name: "Pen Tool", keys: ["P"]),
                .init(name: "Text Tool", keys: ["T"]),
                .init(name: "Shape Tool", keys: ["S"]),
                .init(name: "Highlight Tool", keys: ["H"]),
                .init(name: "Undo", keys: ["⌘", "Z"]),
                .init(name: "Redo", keys: ["⌘", "⇧", "Z"])
            ]
        ),
        ShortcutCategory(
            name: "Actions",
            icon: "bolt",
            color: .purple,
            shortcuts: [
                .init(name: "Copy to Clipboard", keys: ["⌘", "C"]),
                .init(name: "Save", keys: ["⌘", "S"]),
                .init(name: "Share", keys: ["⌘", "⇧", "S"]),
                .init(name: "New Capture", keys: ["⌘", "N"]),
                .init(name: "Close Window", keys: ["⌘", "W"])
            ]
        ),
        ShortcutCategory(
            name: "Navigation",
            icon: "arrow.left.arrow.right",
            color: .green,
            shortcuts: [
                .init(name: "Next Tab", keys: ["⌃", "Tab"]),
                .init(name: "Previous Tab", keys: ["⌃", "⇧", "Tab"]),
                .init(name: "Settings", keys: ["⌘", ","]),
                .init(name: "Keyboard Shortcuts", keys: ["⌘", "/"])
            ]
        )
    ]
}

struct ShortcutInfo: Identifiable {
    let id = UUID()
    let name: String
    let keys: [String]
}

struct ShortcutRow: View {
    let shortcut: ShortcutInfo
    
    var body: some View {
        HStack {
            Text(shortcut.name)
                .font(.body)
            
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(shortcut.keys, id: \.self) { key in
                    Text(key)
                        .font(.body.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tips Browser

/// A view to browse all available tips
struct TipsBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: ContextualTip.Category = .capture
    
    private var categorizedTips: [ContextualTip.Category: [ContextualTip]] {
        Dictionary(grouping: ContextualTip.allTips) { $0.category }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tips & Tricks")
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
            
            HSplitView {
                // Sidebar
                List(selection: $selectedCategory) {
                    Section("Categories") {
                        Label("Capture", systemImage: "camera")
                            .tag(ContextualTip.Category.capture)
                        Label("Editing", systemImage: "pencil.tip.crop.circle")
                            .tag(ContextualTip.Category.editing)
                        Label("Shortcuts", systemImage: "keyboard")
                            .tag(ContextualTip.Category.shortcuts)
                        Label("Productivity", systemImage: "bolt")
                            .tag(ContextualTip.Category.productivity)
                    }
                }
                .frame(minWidth: 150, idealWidth: 200)
                
                // Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let tips = categorizedTips[selectedCategory] {
                            ForEach(tips) { tip in
                                TipCard(tip: tip)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 600, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct TipCard: View {
    let tip: ContextualTip
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tip.icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(tip.title)
                    .font(.headline)
                Text(tip.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Previews

#Preview("Contextual Tip") {
    ZStack {
        Color.gray.opacity(0.2)
        
        ContextualTipView(tip: .switchSelectionMode) { permanently in
            print("Dismissed: \(permanently)")
        }
    }
    .frame(width: 600, height: 400)
}

#Preview("Keyboard Shortcuts") {
    KeyboardShortcutsView()
}

#Preview("Tips Browser") {
    TipsBrowserView()
}
