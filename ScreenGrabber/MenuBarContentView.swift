//
//  MenuBarContentView.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import SwiftData
import UserNotifications

enum OpenOption: String, CaseIterable, Identifiable {
    case clipboard = "clipboard"
    case saveToFile = "save_to_file"
    case preview = "preview"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .saveToFile: return "Save"
        case .preview: return "Preview"
        }
    }
    
    var icon: String {
        switch self {
        case .clipboard: return "doc.on.clipboard"
        case .saveToFile: return "folder"
        case .preview: return "eye"
        }
    }
}

enum ScreenOption: String, CaseIterable, Identifiable {
    case selectedArea = "selected_area"
    case window = "window"
    case fullScreen = "full_screen"
    case scrollingCapture = "scrolling_capture"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .selectedArea: return "Area"
        case .window: return "Window"
        case .fullScreen: return "Full Screen"
        case .scrollingCapture: return "Scrolling"
        }
    }
    
    var icon: String {
        switch self {
        case .selectedArea: return "rectangle.dashed"
        case .window: return "macwindow"
        case .fullScreen: return "display"
        case .scrollingCapture: return "scroll"
        }
    }
}

struct MenuBarContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showHotkeySheet = false
    @State private var currentHotkey = "⌘⇧C"
    @State private var selectedOpenOption: OpenOption = .clipboard
    @State private var selectedScreenOption: ScreenOption = .selectedArea
    @State private var recentScreenshots: [URL] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header and Primary Action
            VStack(spacing: 16) {
                // App Title with Icon
                HStack(spacing: 10) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                        .foregroundStyle(.accent)
                    
                    Text("Screen Grabber")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                // Primary Capture Button - Redesigned for better contrast and a cleaner look
                Button(action: quickCapture) {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.2))
                            .clipShape(Circle())
                    
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Take Screenshot")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text(currentHotkey)
                                .font(.caption)
                                .opacity(0.9)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .accent.opacity(0.3), radius: 8, x: 0, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .colorScheme(.dark) // This ensures the text and icon are always light, providing contrast against the accent color.
            }
            .padding()
            
            // Capture Options - Improved Design
            VStack(spacing: 16) {
                // Capture Method Section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Capture Method", systemImage: "viewfinder")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    HStack(spacing: 6) {
                        ForEach(ScreenOption.allCases) { option in
                            OptionButton(
                                icon: option.icon,
                                label: option.displayName,
                                isSelected: selectedScreenOption == option
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedScreenOption = option
                                }
                            }
                        }
                    }
                }
                
                // Output Method Section
                VStack(alignment: .leading, spacing: 8) {
                    Label("Save To", systemImage: "square.and.arrow.down")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    HStack(spacing: 6) {
                        ForEach(OpenOption.allCases) { option in
                            OptionButton(
                                icon: option.icon,
                                label: option.displayName,
                                isSelected: selectedOpenOption == option
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedOpenOption = option
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Divider().padding(.vertical, 12)
            
            // Recent Captures - Improved Design
            if recentScreenshots.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color.accent.opacity(0.1))
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.accent, .accent.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    
                    VStack(spacing: 4) {
                        Text("No Recent Captures")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                        
                        Text("Take your first screenshot")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .frame(maxHeight: 140)
            } else {
                VStack(spacing: 8) {
                    HStack {
                        Label("Recent Captures", systemImage: "clock.arrow.circlepath")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(recentScreenshots.prefix(5).count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.accent.opacity(0.8))
                            )
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(recentScreenshots.prefix(5), id: \.self) { fileURL in
                                RecentCaptureRow(fileURL: fileURL)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxHeight: 200)
                }
            }
            
            Spacer()
            
            // Footer with settings and actions - Improved Design
            VStack(spacing: 0) {
                Divider()
                
                HStack(spacing: 8) {
                    // Hotkey Button
                    MenuActionButton(
                        icon: "keyboard",
                        label: currentHotkey,
                        color: .blue
                    ) {
                        showHotkeySheet = true
                    }
                    
                    // Library Button
                    MenuActionButton(
                        icon: "square.grid.2x2",
                        label: "Library",
                        color: .purple
                    ) {
                        NSApp.sendAction(#selector(NSWindowController.showWindow(_:)), to: nil, from: nil)
                        if let mainApp = NSApp.windows.first(where: { $0.windowNumber > 0 && $0.isVisible }) {
                            mainApp.makeKeyAndOrderFront(nil)
                        }
                    }
                    
                    // Quit Button
                    MenuActionButton(
                        icon: "power",
                        label: "Quit",
                        color: .red
                    ) {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .padding()
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
        .frame(width: 340)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear(perform: loadSettings)
        .sheet(isPresented: $showHotkeySheet) {
            HotkeyConfigView(currentHotkey: $currentHotkey, onSave: setupGlobalHotkey)
        }
    }
}

// MARK: - Subviews
extension MenuBarContentView {
    struct RecentCaptureRow: View {
        let fileURL: URL
        @State private var thumbnail: NSImage?
        @State private var isHovered = false
        
        var body: some View {
            Button(action: { NSWorkspace.shared.open(fileURL) }) {
                HStack(spacing: 10) {
                    // Thumbnail with better styling
                    Group {
                        if let thumbnail = thumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.accent.opacity(0.1))
                                
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.accent)
                            }
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    
                    // File info
                    VStack(alignment: .leading, spacing: 3) {
                        Text(fileURL.lastPathComponent)
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        Text(formatFileDate())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer(minLength: 0)
                    
                    // Action icon
                    Image(systemName: isHovered ? "arrow.up.forward.circle.fill" : "arrow.up.forward.circle")
                        .font(.system(size: 16))
                        .foregroundColor(isHovered ? .accent : .secondary)
                        .animation(.easeInOut(duration: 0.2), value: isHovered)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHovered ? Color.accent.opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isHovered ? Color.accent.opacity(0.3) : Color.clear,
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
            .onAppear(perform: loadThumbnail)
            .contextMenu {
                Button("Open") {
                    NSWorkspace.shared.open(fileURL)
                }
                
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path)
                }
                
                Divider()
                
                Button("Copy to Clipboard") {
                    if let image = NSImage(contentsOf: fileURL) {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.writeObjects([image])
                    }
                }
            }
        }
        
        private func loadThumbnail() {
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = NSImage(contentsOf: fileURL) else { return }
                
                let thumbnailSize = NSSize(width: 80, height: 80)
                let newImage = NSImage(size: thumbnailSize)
                newImage.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: thumbnailSize), from: .zero, operation: .sourceOver, fraction: 1)
                newImage.unlockFocus()
                
                DispatchQueue.main.async {
                    self.thumbnail = newImage
                }
            }
        }
        
        private func formatFileDate() -> String {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let creationDate = attributes[.creationDate] as? Date {
                    let formatter = RelativeDateTimeFormatter()
                    formatter.unitsStyle = .abbreviated
                    return formatter.localizedString(for: creationDate, relativeTo: Date())
                }
            } catch {
                print("Error getting file attributes: \(error)")
            }
            return "Unknown"
        }
    }
    
    struct HotkeyConfigView: View {
        @Binding var currentHotkey: String
        let onSave: (String) -> Bool
        @Environment(\.dismiss) private var dismiss
        @State private var newHotkey: String
        @State private var conflictMessage: String?
        
        init(currentHotkey: Binding<String>, onSave: @escaping (String) -> Bool) {
            self._currentHotkey = currentHotkey
            self.onSave = onSave
            self._newHotkey = State(initialValue: currentHotkey.wrappedValue)
        }
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Set Global Hotkey")
                    .font(.title2.weight(.bold))
                
                Text("Press a key combination to trigger a capture from anywhere.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                TextField("Enter hotkey (e.g., ⌘⇧C)", text: $newHotkey)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .font(.title3)
                
                if let conflictMessage = conflictMessage {
                    Text(conflictMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                HStack {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                    
                    Button("Save") {
                        if onSave(newHotkey) {
                            dismiss()
                        } else {
                            conflictMessage = "This hotkey is already in use by another application. Please choose a different one."
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newHotkey.isEmpty)
                }
            }
            .padding()
            .frame(width: 350)
        }
    }
}

// MARK: - Action Functions
extension MenuBarContentView {
    
    private func loadSettings() {
        currentHotkey = UserDefaults.standard.string(forKey: "grabScreenHotkey") ?? "⌘⇧C"
        
        if let savedScreenOption = UserDefaults.standard.string(forKey: "selectedScreenOption"),
           let screenOption = ScreenOption(rawValue: savedScreenOption) {
            selectedScreenOption = screenOption
        }
        
        if let savedOpenOption = UserDefaults.standard.string(forKey: "selectedOpenOption"),
           let openOption = OpenOption(rawValue: savedOpenOption) {
            selectedOpenOption = openOption
        }
        
        loadRecentScreenshots()
    }
    
    private func loadRecentScreenshots() {
        recentScreenshots = ScreenCaptureManager.shared.loadRecentScreenshots()
    }
    
    private func setupGlobalHotkey(hotkey: String) -> Bool {
        let success = GlobalHotkeyManager.shared.registerHotkey(hotkey) {
            DispatchQueue.main.async(execute: self.quickCapture)
        }
        
        if success {
            UserDefaults.standard.set(hotkey, forKey: "grabScreenHotkey")
            currentHotkey = hotkey
            print("Hotkey set to: \(hotkey)")
        } else {
            print("Failed to set hotkey: \(hotkey). It might be in use.")
            // Don't change the stored hotkey if it fails to register.
            // The UI will show the error.
        }
        return success
    }
    
    private func quickCapture() {
        UserDefaults.standard.set(selectedScreenOption.rawValue, forKey: "selectedScreenOption")
        UserDefaults.standard.set(selectedOpenOption.rawValue, forKey: "selectedOpenOption")
        
        ScreenCaptureManager.shared.captureScreen(
            method: selectedScreenOption,
            openOption: selectedOpenOption,
            modelContext: modelContext
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            loadRecentScreenshots()
        }
    }
}

// MARK: - Custom Button Styles and Components

/// Scale button style for the main capture button
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

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
                    .foregroundStyle(.primary) // Let colorScheme handle the color
                    .frame(height: 20)
                
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.primary) // Let colorScheme handle the color
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
                            .fill(.accent) // Use solid color for a cleaner look
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor))
                        
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    }
                }
            )
            .colorScheme(isSelected ? .dark : colorScheme) // KEY FIX: Force dark content on accent color background
            .shadow(
                color: isSelected ? Color.accent.opacity(0.3) : Color.clear,
                radius: isSelected ? 6 : 0,
                x: 0,
                y: isSelected ? 3 : 0
            )
        }
        .buttonStyle(.plain)
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
                            ? color
                            .opacity(0.9)
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

#Preview {
    MenuBarContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
