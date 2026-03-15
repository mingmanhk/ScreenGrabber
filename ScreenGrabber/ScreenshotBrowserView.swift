//
//  ScreenshotBrowserView.swift
//  ScreenGrabber
//
//  Grid view for browsing all screenshots
//

import SwiftUI
import SwiftData
import AppKit

struct ScreenshotBrowserView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Screenshot.captureDate, order: .reverse) private var screenshots: [Screenshot]
    @State private var selectedScreenshot: Screenshot?
    @State private var selectedScreenshots: Set<Screenshot> = []
    @State private var searchText = ""
    @State private var filterType: CaptureType?
    @State private var filterTag: String?
    @State private var showDeleteConfirmation = false
    @State private var isMultiSelectMode = false
    @State private var showFirstTimeDeleteWarning = !UserDefaults.standard.bool(forKey: "hasSeenLibraryDeleteWarning")

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    private var allTags: [String] {
        Array(Set(screenshots.flatMap { $0.tags })).sorted()
    }

    var filteredScreenshots: [Screenshot] {
        var filtered = screenshots

        if !searchText.isEmpty {
            filtered = filtered.filter { screenshot in
                screenshot.filename.localizedCaseInsensitiveContains(searchText) ||
                (screenshot.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        if let type = filterType {
            filtered = filtered.filter { $0.captureType == type.rawValue }
        }

        if let tag = filterTag {
            filtered = filtered.filter { $0.tags.contains(tag) }
        }

        return filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("Search", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 200)

                Picker("Type", selection: $filterType) {
                    Text("All").tag(nil as CaptureType?)
                    ForEach(CaptureType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type as CaptureType?)
                    }
                }
                .frame(width: 120)

                Picker("Tag", selection: $filterTag) {
                    Text("All").tag(nil as String?)
                    ForEach(allTags, id: \.self) { tag in
                        Text(tag).tag(tag as String?)
                    }
                }
                .frame(width: 120)

                Spacer()

                // Multi-select toggle
                Button(action: {
                    isMultiSelectMode.toggle()
                    if !isMultiSelectMode {
                        selectedScreenshots.removeAll()
                    }
                }) {
                    Label(
                        isMultiSelectMode ? "Done Selecting" : "Select Multiple",
                        systemImage: isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                }
                .help(isMultiSelectMode ? "Finish selection" : "Select multiple screenshots")

                // Delete button (enabled when items selected)
                Button(action: {
                    if showFirstTimeDeleteWarning {
                        showFirstTimeDeleteWarning = false
                        UserDefaults.standard.set(true, forKey: "hasSeenLibraryDeleteWarning")
                    }
                    showDeleteConfirmation = true
                }) {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selectedScreenshots.isEmpty)
                .help(selectedScreenshots.isEmpty ? "Select items to delete" : "Delete \(selectedScreenshots.count) selected item(s)")
            }
            .padding()

            // Grid - Using existing ScreenshotThumbnailView with custom wrapper
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredScreenshots) { screenshot in
                        BrowserThumbnailView(
                            screenshot: screenshot,
                            isSelected: isMultiSelectMode ? selectedScreenshots.contains(screenshot) : false,
                            onSelect: { handleThumbnailSelect(screenshot) },
                            onDoubleClick: { openScreenshot(screenshot) }
                        )
                        .contextMenu {
                            ScreenshotContextMenu(screenshot: screenshot, modelContext: modelContext)
                        }
                    }
                }
                .padding()
            }

            // Status bar
            HStack {
                Text("\(filteredScreenshots.count) screenshots")
                if isMultiSelectMode && !selectedScreenshots.isEmpty {
                    Text("• \(selectedScreenshots.count) selected")
                        .foregroundColor(.accentColor)
                }
                Spacer()
                if let selected = selectedScreenshot, !isMultiSelectMode {
                    Text("\(selected.width)×\(selected.height) • \(selected.captureType)")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .alert("Move to Trash?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                deleteSelectedScreenshots()
            }
        } message: {
            if showFirstTimeDeleteWarning {
                Text("Screenshots will be moved to the Trash, not permanently deleted. You can restore them from the Trash later.")
            } else {
                Text("Move \(selectedScreenshots.count) screenshot(s) to Trash?")
            }
        }
        .navigationTitle("Library")
    }

    private func handleThumbnailSelect(_ screenshot: Screenshot) {
        if isMultiSelectMode {
            if selectedScreenshots.contains(screenshot) {
                selectedScreenshots.remove(screenshot)
            } else {
                selectedScreenshots.insert(screenshot)
            }
        } else {
            selectedScreenshot = screenshot
            selectedScreenshots = [screenshot]
        }
    }

    private func openScreenshot(_ screenshot: Screenshot) {
        let fileURL = URL(fileURLWithPath: screenshot.filePath)
        EditorWindowOpener.open(fileURL: fileURL)
    }

    private func deleteSelectedScreenshots() {
        Task {
            for screenshot in selectedScreenshots {
                _ = await CaptureHistoryStore.shared.deleteCapture(screenshot, from: modelContext)
            }
            selectedScreenshots.removeAll()
            if isMultiSelectMode {
                isMultiSelectMode = false
            }
        }
    }
}

// MARK: - Browser Thumbnail View (wrapper for existing ScreenshotThumbnailView)

struct BrowserThumbnailView: View {
    let screenshot: Screenshot
    let isSelected: Bool
    let onSelect: () -> Void
    let onDoubleClick: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Thumbnail with selection overlay
            ZStack(alignment: .topTrailing) {
                if let thumbnailPath = screenshot.thumbnailPath,
                   let image = NSImage(contentsOfFile: thumbnailPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 120)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 120)
                        .cornerRadius(6)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                        )
                }

                // Selection checkbox
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .background(Circle().fill(Color.white))
                        .padding(4)
                }
            }
            .onTapGesture(count: 2) {
                onDoubleClick()
            }
            .onTapGesture {
                onSelect()
            }

            // Filename
            Text(screenshot.filename)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)

            // Metadata
            HStack {
                Text(screenshot.captureDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(screenshot.width)×\(screenshot.height)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - Context Menu

struct ScreenshotContextMenu: View {
    let screenshot: Screenshot
    let modelContext: ModelContext
    @State private var showDeleteConfirmation = false
    @State private var showFirstTimeDeleteWarning = !UserDefaults.standard.bool(forKey: "hasSeenLibraryDeleteWarning")

    var body: some View {
        Button("Open in Editor") {
            let fileURL = URL(fileURLWithPath: screenshot.filePath)
            EditorWindowOpener.open(fileURL: fileURL)
        }

        Button("Copy to Clipboard") {
            if let image = NSImage(contentsOfFile: screenshot.filePath) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([image])
            }
        }

        Button("Reveal in Finder") {
            let fileURL = URL(fileURLWithPath: screenshot.filePath)
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        }

        Divider()

        if !screenshot.tags.isEmpty {
            Menu("Remove Tag") {
                ForEach(screenshot.tags, id: \.self) { tag in
                    Button(tag) {
                        var updated = screenshot.tags
                        updated.removeAll { $0 == tag }
                        screenshot.updateMetadata(tags: updated)
                    }
                }
            }
        }

        Button("Add Tag...") {
            addTag(to: screenshot)
        }

        Divider()

        Button("Delete", role: .destructive) {
            if showFirstTimeDeleteWarning {
                showFirstTimeDeleteWarning = false
                UserDefaults.standard.set(true, forKey: "hasSeenLibraryDeleteWarning")
            }
            showDeleteConfirmation = true
        }
        .alert("Move to Trash?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Move to Trash", role: .destructive) {
                Task {
                    _ = await CaptureHistoryStore.shared.deleteCapture(screenshot, from: modelContext)
                }
            }
        } message: {
            if showFirstTimeDeleteWarning {
                Text("Screenshots will be moved to the Trash, not permanently deleted. You can restore them from the Trash later.")
            } else {
                Text("Move this screenshot to Trash?")
            }
        }
    }

    private func addTag(to screenshot: Screenshot) {
        let alert = NSAlert()
        alert.messageText = "Add Tag"
        alert.informativeText = "Enter a tag name for this screenshot:"
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.placeholderString = "e.g. work, design, bug"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let tag = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty, !screenshot.tags.contains(tag) else { return }

        var updated = screenshot.tags
        updated.append(tag)
        screenshot.updateMetadata(tags: updated)
    }
}
