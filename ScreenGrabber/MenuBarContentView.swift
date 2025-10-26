//
//  MenuBarContentView.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import SwiftData
import UserNotifications

enum OpenOption: String, CaseIterable {
    case clipboard = "clipboard"
    case saveToFile = "save_to_file"  
    case preview = "preview"
    
    var displayName: String {
        switch self {
        case .clipboard: return "Clipboard"
        case .saveToFile: return "Save to File"
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

enum ScreenOption: String, CaseIterable {
    case selectedArea = "selected_area"
    case window = "window"
    case fullScreen = "full_screen"
    case scrollingCapture = "scrolling_capture"
    
    var displayName: String {
        switch self {
        case .selectedArea: return "Selected Area"
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
    
    var shortcut: String {
        switch self {
        case .selectedArea: return "⌘⇧4"
        case .window: return "⌘⇧4 + Space"
        case .fullScreen: return "⌘⇧3"
        case .scrollingCapture: return "⌘⇧S"
        }
    }
}

struct MenuBarContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showHotkeySheet = false
    @State private var currentHotkey = "⌘⇧C" // Default hotkey changed to Shift + Command + C
    @State private var selectedOpenOption: OpenOption = .clipboard // Default to clipboard
    @State private var selectedScreenOption: ScreenOption = .selectedArea // Default to Selected Area
    @State private var recentScreenshots: [URL] = []
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Spacer()
                
                HStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .foregroundColor(.accentColor)
                        .font(.title2)
                    
                    Text("Screen Grabber")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            Divider()
            
            // Screen options
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "display")
                        .foregroundColor(.accentColor)
                    Text("Screen")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal)
                
                HStack(spacing: 6) {
                    ForEach(ScreenOption.allCases, id: \.self) { option in
                        ScreenOptionButton(
                            option: option,
                            isSelected: selectedScreenOption == option,
                            action: { 
                                selectedScreenOption = option
                                UserDefaults.standard.set(option.rawValue, forKey: "selectedScreenOption")
                            }
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // Open in options
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.accentColor)
                    Text("Open in")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal)
                
                HStack(spacing: 8) {
                    ForEach(OpenOption.allCases, id: \.self) { option in
                        OpenOptionButton(
                            option: option,
                            isSelected: selectedOpenOption == option,
                            action: { 
                                selectedOpenOption = option
                                UserDefaults.standard.set(option.rawValue, forKey: "selectedOpenOption")
                            }
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // Recent captures
            if !recentScreenshots.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.accentColor)
                        Text("Recent Captures")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(recentScreenshots.prefix(5), id: \.self) { fileURL in
                                RecentCaptureRow(fileURL: fileURL)
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
                
                Divider()
            }
            
            // Utility options
            HStack(spacing: 16) {
                VStack(spacing: 8) {
                    Button(action: { showHotkeySheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "keyboard")
                            Text("Set Hotkey")
                            Text("(\(currentHotkey))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    // Debug button
                    Button(action: { 
                        print("🧪 Running screenshot test...")
                        ScreenCaptureManager.shared.testFullScreenshotProcess()
                    }) {
                        Text("Test Screenshot")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                }
                .sheet(isPresented: $showHotkeySheet) {
                    HotkeyConfigView(currentHotkey: $currentHotkey, onHotkeyChanged: { newHotkey in
                        setupGlobalHotkey(hotkey: newHotkey)
                    })
                }
                
                Spacer()
                
                Button(action: { quickCapture() }) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor.opacity(0.9), Color.pink.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 88, height: 88)
                                .shadow(color: Color.accentColor.opacity(0.35), radius: 12, x: 0, y: 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )

                            Circle()
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 4)
                                .frame(width: 70, height: 70)

                            Image(systemName: "camera.aperture")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 4)
                        }

                        Text("Grab Screen")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.primary)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            // App info at bottom
            VStack(spacing: 4) {
                Text("Screen Grabber")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Also available as main app in Dock")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(width: 400, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            _ = ScreenCaptureManager.shared.createScreenGrabberFolder()
            loadRecentScreenshots()
            
            // Load saved preferences
            let savedHotkey = UserDefaults.standard.string(forKey: "grabScreenHotkey") ?? "⌘⇧C"
            currentHotkey = savedHotkey
            
            if let savedScreenOption = UserDefaults.standard.string(forKey: "selectedScreenOption"),
               let screenOption = ScreenOption(rawValue: savedScreenOption) {
                selectedScreenOption = screenOption
            }
            
            if let savedOpenOption = UserDefaults.standard.string(forKey: "selectedOpenOption"),
               let openOption = OpenOption(rawValue: savedOpenOption) {
                selectedOpenOption = openOption
            }
        }
    }
}

struct RecentCaptureRow: View {
    let fileURL: URL
    
    var body: some View {
        HStack {
            Image(systemName: "photo")
                .font(.caption)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(fileURL.lastPathComponent)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(formatFileDate())
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: { openFile() }) {
                Image(systemName: "eye")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            
            Button(action: { shareFile() }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
        .padding(.horizontal)
    }
    
    private func formatFileDate() -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let creationDate = attributes[.creationDate] as? Date {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                formatter.dateStyle = .none
                return formatter.string(from: creationDate)
            }
        } catch {
            print("Error getting file attributes: \(error)")
        }
        return ""
    }
    
    private func openFile() {
        NSWorkspace.shared.open(fileURL)
    }
    
    private func shareFile() {
        let sharingServicePicker = NSSharingServicePicker(items: [fileURL])
        if let view = NSApp.keyWindow?.contentView {
            sharingServicePicker.show(relativeTo: NSRect(x: 0, y: 0, width: 1, height: 1), of: view, preferredEdge: .minY)
        }
    }
}

struct OpenOptionButton: View {
    let option: OpenOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: option.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : .accentColor)
                
                Text(option.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(minWidth: 70, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.clear : Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ScreenOptionButton: View {
    let option: ScreenOption
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: option.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : .accentColor)
                
                Text(option.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                
                Text(option.shortcut)
                    .font(.system(size: 7))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(minWidth: 60, minHeight: 65)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.clear : Color.accentColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Functions
extension MenuBarContentView {
    
    private func loadRecentScreenshots() {
        recentScreenshots = ScreenCaptureManager.shared.loadRecentScreenshots()
    }
    
    private func setupGlobalHotkey(hotkey: String) {
        // Store the hotkey preference
        UserDefaults.standard.set(hotkey, forKey: "grabScreenHotkey")
        currentHotkey = hotkey
        
        // Register the global hotkey
        GlobalHotkeyManager.shared.registerHotkey(hotkey) {
            DispatchQueue.main.async {
                // Trigger screen capture using selected settings
                self.executeGlobalHotkeyCapture()
            }
        }
        
        print("Hotkey set to: \(hotkey)")
    }
    
    func executeGlobalHotkeyCapture() {
        // Use the currently selected screen and open options
        ScreenCaptureManager.shared.captureScreen(
            method: selectedScreenOption,
            openOption: selectedOpenOption,
            modelContext: modelContext
        )
        
        // Update recent screenshots after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            loadRecentScreenshots()
        }
    }
    
    private func quickCapture() {
        // Use the ScreenCaptureManager to handle the capture
        ScreenCaptureManager.shared.captureScreen(
            method: selectedScreenOption,
            openOption: selectedOpenOption,
            modelContext: modelContext
        )
        
        // Update recent screenshots after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            loadRecentScreenshots()
        }
    }
}

#Preview {
    MenuBarContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

struct HotkeyConfigView: View {
    @Binding var currentHotkey: String
    let onHotkeyChanged: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedHotkey: String
    @State private var customHotkey: String = ""
    @State private var isEditingCustom: Bool = false
    
    let availableHotkeys = [
        "⌘⇧C": "Command + Shift + C",
        "⌘⇧G": "Command + Shift + G",
        "⌘⇧S": "Command + Shift + S", 
        "⌘⇧X": "Command + Shift + X",
        "⌘⇧Z": "Command + Shift + Z",
        "⌘⌥G": "Command + Option + G",
        "⌘⌥S": "Command + Option + S"
    ]
    
    init(currentHotkey: Binding<String>, onHotkeyChanged: @escaping (String) -> Void) {
        self._currentHotkey = currentHotkey
        self.onHotkeyChanged = onHotkeyChanged
        self._selectedHotkey = State(initialValue: currentHotkey.wrappedValue)
        self._customHotkey = State(initialValue: currentHotkey.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "keyboard")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                
                Text("Set Grab Screen Hotkey")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Description
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose a global hotkey to quickly trigger the Grab Screen function:")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("Current hotkey: \(availableHotkeys[currentHotkey] ?? currentHotkey)")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal)
            
            // Custom hotkey input
            VStack(alignment: .leading, spacing: 8) {
                Text("Custom Hotkey:")
                    .font(.headline)
                    .padding(.horizontal)
                
                TextField("Enter hotkey (e.g., ⌘⇧C)", text: $customHotkey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .onSubmit {
                        selectedHotkey = customHotkey
                        isEditingCustom = false
                    }
                    .onChange(of: customHotkey) { oldValue, newValue in
                        selectedHotkey = newValue
                        isEditingCustom = true
                    }
                
                Text("Tip: Use ⌘ (Command), ⇧ (Shift), ⌥ (Option), ⌃ (Control) + any letter")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            Divider()
            
            // Preset hotkey options
            VStack(alignment: .leading, spacing: 8) {
                Text("Preset Options:")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(availableHotkeys.keys.sorted()), id: \.self) { key in
                            HotkeyOption(
                                shortcut: key,
                                description: availableHotkeys[key] ?? key,
                                isSelected: selectedHotkey == key && !isEditingCustom,
                                action: {
                                    selectedHotkey = key
                                    customHotkey = key
                                    isEditingCustom = false
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save Hotkey") {
                    onHotkeyChanged(selectedHotkey)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedHotkey == currentHotkey || selectedHotkey.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 600)
    }
}

struct HotkeyOption: View {
    let shortcut: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text("Press \(shortcut) anywhere")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

