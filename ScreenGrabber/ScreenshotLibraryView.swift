//
//  ScreenshotLibraryView.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI
import SwiftData
import AppKit

protocol OptionProtocol {
    var icon: String { get }
    var displayName: String { get }
}

extension ScreenOption: OptionProtocol {}
extension OpenOption: OptionProtocol {}

struct ScreenshotLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \Screenshot.captureDate, order: .reverse) private var screenshots: [Screenshot]
    
    @State private var selectedScreenOption: ScreenOption = .selectedArea
    @State private var selectedOpenOption: OpenOption = .clipboard
    @State private var currentHotkey = "⌘⇧C"
    @State private var recentScreenshots: [URL] = []
    @State private var searchText = ""
    @State private var selectedSortOption: SortOption = .dateNewest
    @State private var showHotkeySheet = false
    
    enum SortOption: String, CaseIterable {
        case dateNewest = "dateNewest"
        case dateOldest = "dateOldest"
        case nameAZ = "nameAZ"
        case nameZA = "nameZA"
        case sizeSmall = "sizeSmall"
        case sizeLarge = "sizeLarge"
        
        var displayName: String {
            switch self {
            case .dateNewest: return "Date (Newest)"
            case .dateOldest: return "Date (Oldest)"
            case .nameAZ: return "Name (A-Z)"
            case .nameZA: return "Name (Z-A)"
            case .sizeSmall: return "Size (Smallest)"
            case .sizeLarge: return "Size (Largest)"
            }
        }
    }
    
    var filteredScreenshots: [URL] {
        var filtered = recentScreenshots
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { url in
                url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply sorting
        switch selectedSortOption {
        case .dateNewest:
            filtered.sort { url1, url2 in
                let date1 = getFileDate(url1) ?? Date.distantPast
                let date2 = getFileDate(url2) ?? Date.distantPast
                return date1 > date2
            }
        case .dateOldest:
            filtered.sort { url1, url2 in
                let date1 = getFileDate(url1) ?? Date.distantFuture
                let date2 = getFileDate(url2) ?? Date.distantFuture
                return date1 < date2
            }
        case .nameAZ:
            filtered.sort { $0.lastPathComponent < $1.lastPathComponent }
        case .nameZA:
            filtered.sort { $0.lastPathComponent > $1.lastPathComponent }
        case .sizeSmall, .sizeLarge:
            filtered.sort { url1, url2 in
                let size1 = getFileSize(url1)
                let size2 = getFileSize(url2)
                return selectedSortOption == .sizeSmall ? size1 < size2 : size1 > size2
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
        .navigationTitle("Screen Grabber")
        .onAppear {
            loadSettings()
            loadRecentScreenshots()
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            settingsSection
            Spacer()
            tipsSection
        }
        .frame(minWidth: 300)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "camera.viewfinder")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading) {
                    Text("Screen Grabber")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("\(recentScreenshots.count) screenshots")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Capture Settings")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal)
            
            screenMethodSection
            outputMethodSection
            
            Divider()
                .padding(.horizontal)
            
            hotkeyButton
            folderAccessButton
        }
        .padding(.vertical)
    }
    
    @ViewBuilder
    private var screenMethodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screen Method")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 4) {
                ForEach(ScreenOption.allCases, id: \.self) { option in
                    optionButton(
                        option: option,
                        isSelected: selectedScreenOption == option,
                        action: {
                            selectedScreenOption = option
                            UserDefaults.standard.set(option.rawValue, forKey: "selectedScreenOption")
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var outputMethodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output Method")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 4) {
                ForEach(OpenOption.allCases, id: \.self) { option in
                    optionButton(
                        option: option,
                        isSelected: selectedOpenOption == option,
                        action: {
                            selectedOpenOption = option
                            UserDefaults.standard.set(option.rawValue, forKey: "selectedOpenOption")
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func optionButton<T: OptionProtocol>(option: T, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: option.icon)
                    .frame(width: 20)
                Text(option.displayName)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor.opacity(0.1) : Color.clear
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
    }
    
    @ViewBuilder
    private var hotkeyButton: some View {
        Button(action: { showHotkeySheet = true }) {
            HStack {
                Image(systemName: "keyboard")
                    .frame(width: 20)
                VStack(alignment: .leading) {
                    Text("Global Hotkey")
                        .fontWeight(.medium)
                    Text(currentHotkey)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .padding(.horizontal)
        .sheet(isPresented: $showHotkeySheet) {
            HotkeyConfigView(currentHotkey: $currentHotkey, onSave: { newHotkey in
                setupGlobalHotkey(hotkey: newHotkey)
                return true
            })
        }
    }
    
    @ViewBuilder
    private var folderAccessButton: some View {
        Button(action: openScreenGrabberFolder) {
            HStack {
                Image(systemName: "folder")
                    .frame(width: 20)
                VStack(alignment: .leading) {
                    Text("Screenshots Folder")
                        .fontWeight(.medium)
                    Text("Open in Finder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundColor(.primary)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💡 Tips")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
            
            Text("• Use menu bar for quick access")
            Text("• Double-click to edit screenshots")
            Text("• Right-click for more options")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(8)
        .padding()
    }
    
    @ViewBuilder
    private var detailContent: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                toolbarSection
                Divider()
                screenshotsContent
            }
            bottomActionBar
        }
    }
    
    @ViewBuilder
    private var toolbarSection: some View {
        HStack {
            searchBar
            Spacer()
            sortControls
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    @ViewBuilder
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search screenshots...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .frame(maxWidth: 300)
    }
    
    @ViewBuilder
    private var sortControls: some View {
        HStack(spacing: 12) {
            Text("Sort:")
                .foregroundColor(.secondary)
            
            Picker("Sort", selection: $selectedSortOption) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .frame(width: 150)
            
            Button(action: loadRecentScreenshots) {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
        }
    }
    
    @ViewBuilder
    private var screenshotsContent: some View {
        if filteredScreenshots.isEmpty {
            emptyStateView
        } else {
            screenshotsGrid
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if recentScreenshots.isEmpty {
                noScreenshotsView
            } else {
                noResultsView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var noScreenshotsView: some View {
        Image(systemName: "photo.on.rectangle")
            .font(.system(size: 80))
            .foregroundColor(.secondary)
        
        Text("No Screenshots Yet")
            .font(.title)
            .fontWeight(.semibold)
        
        Text("Capture your first screenshot to get started!")
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        
        captureButton(style: .large)
    }
    
    @ViewBuilder
    private var noResultsView: some View {
        Image(systemName: "magnifyingglass")
            .font(.system(size: 60))
            .foregroundColor(.secondary)
        
        Text("No Results Found")
            .font(.title2)
            .fontWeight(.semibold)
        
        Text("Try a different search term")
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private var screenshotsGrid: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: 4), spacing: 20) {
                ForEach(filteredScreenshots, id: \.self) { fileURL in
                    ScreenshotGridItem(fileURL: fileURL) {
                        openImageEditor(for: fileURL)
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var bottomActionBar: some View {
        HStack {
            captureButton(style: .compact)
            Spacer(minLength: 0)
            refreshButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(actionBarBackground)
        .padding(.bottom, 16)
    }
    
    private enum CaptureButtonStyle {
        case large
        case compact
    }
    
    @ViewBuilder
    private func captureButton(style: CaptureButtonStyle) -> some View {
        Button(action: quickCapture) {
            HStack(spacing: style == .compact ? 12 : 10) {
                if style == .compact {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 36, height: 36)
                        Image(systemName: "camera.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else {
                    Image(systemName: "camera.fill")
                        .font(.headline)
                }
                
                Text(style == .compact ? "Capture" : "Capture Screenshot")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, style == .compact ? 12 : 10)
            .background(captureButtonBackground(style: style))
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func captureButtonBackground(style: CaptureButtonStyle) -> some View {
        Capsule(style: style == .compact ? .continuous : .circular)
            .fill(LinearGradient(
                colors: [
                    Color.accentColor.opacity(style == .compact ? 0.98 : 1.0),
                    Color.accentColor.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .shadow(
                color: Color.black.opacity(style == .compact ? 0.25 : 0.15),
                radius: style == .compact ? 14 : 8,
                x: 0,
                y: style == .compact ? 10 : 6
            )
    }
    
    @ViewBuilder
    private var refreshButton: some View {
        Button(action: loadRecentScreenshots) {
            Image(systemName: "arrow.clockwise")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var actionBarBackground: some View {
        VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08))
            )
            .padding(.horizontal, 12)
    }
    
    // MARK: - Actions
    
    private func loadSettings() {
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
    
    private func loadRecentScreenshots() {
        recentScreenshots = ScreenCaptureManager.shared.loadRecentScreenshots()
    }
    
    private func quickCapture() {
        ScreenCaptureManager.shared.captureScreen(
            method: selectedScreenOption,
            openOption: selectedOpenOption,
            modelContext: modelContext
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            loadRecentScreenshots()
        }
    }
    
    private func setupGlobalHotkey(hotkey: String) {
        UserDefaults.standard.set(hotkey, forKey: "grabScreenHotkey")
        currentHotkey = hotkey
        
        _ = GlobalHotkeyManager.shared.registerHotkey(hotkey) {
            DispatchQueue.main.async {
                self.quickCapture()
            }
        }
    }
    
    private func openScreenGrabberFolder() {
        let folderURL = ScreenCaptureManager.shared.getScreenGrabberFolderURL()
        NSWorkspace.shared.open(folderURL)
    }
    
    private func openImageEditor(for fileURL: URL) {
        openWindow(value: fileURL)
    }
    
    // MARK: - Helper Methods
    
    private func getFileDate(_ url: URL) -> Date? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.creationDate] as? Date
        } catch {
            return nil
        }
    }
    
    private func getFileSize(_ url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

#Preview {
    ScreenshotLibraryView()
        .modelContainer(for: Item.self, inMemory: true)
}
