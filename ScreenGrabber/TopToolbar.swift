//
//  TopToolbar.swift
//  ScreenGrabber
//
//  Top toolbar with app branding, navigation tabs, and quick actions.
//

import SwiftUI

enum AppNavigationItem: String, CaseIterable, Identifiable {
    case library  = "Library"
    case editor   = "Editor"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .library:  return "photo.stack"
        case .editor:   return "pencil.and.scribble"
        case .settings: return "gearshape"
        }
    }

    var keyboardShortcut: KeyboardShortcut {
        switch self {
        case .library:  return KeyboardShortcut("1", modifiers: .command)
        case .editor:   return KeyboardShortcut("2", modifiers: .command)
        case .settings: return KeyboardShortcut("3", modifiers: .command)
        }
    }
}

struct TopToolbar: View {
    @Binding var selectedView: AppNavigationItem

    var body: some View {
        HStack(spacing: 0) {
            // App branding
            HStack(spacing: 8) {
                Image(systemName: "camera.on.rectangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Screen Grabber")
                    .font(.system(size: 16, weight: .bold))
            }
            .padding(.leading, 20)

            Spacer()

            // Navigation tabs
            HStack(spacing: 4) {
                ForEach(AppNavigationItem.allCases) { item in
                    NavigationTabButton(
                        title: item.rawValue,
                        icon: item.icon,
                        isSelected: selectedView == item
                    ) {
                        selectedView = item
                    }
                    .keyboardShortcut(item.keyboardShortcut)
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            // Quick actions
            HStack(spacing: 10) {
                Button(action: openScreenshotsFolder) {
                    Image(systemName: "folder")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Open Screenshots Folder (⌘⇧F)")
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button(action: openHelp) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Help")
            }
            .padding(.trailing, 20)
        }
        .frame(height: 52)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func openScreenshotsFolder() {
        Task { @MainActor in
            if let url = await UnifiedCaptureManager.shared.getCapturesFolderURL() {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func openHelp() {
        NSWorkspace.shared.open(URL(string: "https://github.com")!)
    }
}

// MARK: - Navigation Tab Button

struct NavigationTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    TopToolbar(selectedView: .constant(.library))
        .frame(width: 800)
}
