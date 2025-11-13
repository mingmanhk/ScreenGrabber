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
                Text("Screen Grabber")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                // Primary Capture Button
                Button(action: quickCapture) {
                    Label("Capture Screen", systemImage: "camera.fill")
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .shadow(color: .accentColor.opacity(0.3), radius: 8, y: 4)
            }
            .padding()
            
            // Capture Options
            VStack(spacing: 12) {
                Picker("Capture Method", selection: $selectedScreenOption) {
                    ForEach(ScreenOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                
                Picker("Output", selection: $selectedOpenOption) {
                    ForEach(OpenOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal)
            
            Divider().padding(.vertical)
            
            // Recent Captures
            if recentScreenshots.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40, weight: .thin))
                        .foregroundColor(.secondary)
                    Text("No Recent Captures")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                HStack {
                    Text("Recent Captures")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(recentScreenshots.prefix(5), id: \.self) { fileURL in
                            RecentCaptureRow(fileURL: fileURL)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 200)
            }
            
            Spacer()
            
            // Footer with settings and quit
            HStack(spacing: 12) {
                Button(action: { showHotkeySheet = true }) {
                    Label(currentHotkey, systemImage: "keyboard")
                }
                .help("Set Global Hotkey")
                
                Spacer()
                
                Button(action: {
                    NSApp.sendAction(Selector(("showWindow:")), to: nil, from: nil)
                    if let mainApp = NSApp.windows.first(where: { $0.windowNumber > 0 && $0.isVisible }) {
                         mainApp.makeKeyAndOrderFront(nil)
                     }
                }) {
                    Label("Show Library", systemImage: "square.grid.2x2")
                }
                .help("Open Screenshot Library")
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Label("Quit", systemImage: "power")
                }
                .help("Quit Screen Grabber")
            }
            .buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .font(.body.weight(.medium))
            .foregroundColor(.secondary)
            .padding()
            .background(.black.opacity(0.1))
        }
        .frame(width: 320)
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
        
        var body: some View {
            HStack {
                Group {
                    if let thumbnail = thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                
                Text(fileURL.lastPathComponent)
                    .font(.caption)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { NSWorkspace.shared.open(fileURL) }) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .onAppear(perform: loadThumbnail)
        }
        
        private func loadThumbnail() {
            DispatchQueue.global(qos: .userInitiated).async {
                guard let image = NSImage(contentsOf: fileURL) else { return }
                
                let thumbnailSize = NSSize(width: 64, height: 64)
                let newImage = NSImage(size: thumbnailSize)
                newImage.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: thumbnailSize), from: .zero, operation: .sourceOver, fraction: 1)
                newImage.unlockFocus()
                
                DispatchQueue.main.async {
                    self.thumbnail = newImage
                }
            }
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

#Preview {
    MenuBarContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
