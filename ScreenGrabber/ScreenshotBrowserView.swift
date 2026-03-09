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
    @State private var searchText = ""
    @State private var filterType: CaptureType?
    @State private var filterTag: String?

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
            // Search and filter bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search screenshots...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Divider()
                    .frame(height: 20)

                Menu {
                    Button("All Types") {
                        filterType = nil
                    }
                    Divider()
                    ForEach(CaptureType.allCases) { type in
                        Button(type.displayName) {
                            filterType = type
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(filterType?.displayName ?? "All Types")
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                }
                .menuStyle(.borderlessButton)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))

            // Tag filter chips
            if !allTags.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allTags, id: \.self) { tag in
                            TagFilterChip(tag: tag, isSelected: filterTag == tag) {
                                filterTag = filterTag == tag ? nil : tag
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .background(Color(NSColor.controlBackgroundColor))
            }

            Divider()

            // Screenshot grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredScreenshots) { screenshot in
                        ScreenshotThumbnailView(screenshot: screenshot)
                            .onTapGesture {
                                selectedScreenshot = screenshot
                            }
                            .contextMenu {
                                screenshotContextMenu(for: screenshot)
                            }
                    }
                }
                .padding(16)
            }

            if filteredScreenshots.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("No Screenshots")
                        .font(.title3)
                        .fontWeight(.medium)

                    Text(searchText.isEmpty && filterTag == nil
                         ? "Capture your first screenshot to get started"
                         : "No results found")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $selectedScreenshot) { screenshot in
            ScreenshotDetailView(screenshot: screenshot)
        }
    }

    @ViewBuilder
    private func screenshotContextMenu(for screenshot: Screenshot) -> some View {
        Button("Open in Editor") {
            EditorWindowHelper.shared.openEditor(for: screenshot)
        }

        Button("Show in Finder") {
            NSWorkspace.shared.selectFile(screenshot.filePath, inFileViewerRootedAtPath: "")
        }

        Button("Copy to Clipboard") {
            if let image = NSImage(contentsOf: screenshot.fileURL) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([image])
            }
        }

        Divider()

        Button(screenshot.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
            screenshot.toggleFavorite()
        }

        Button("Add Tag...") {
            addTag(to: screenshot)
        }

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

        Divider()

        Button("Delete", role: .destructive) {
            Task {
                await CaptureHistoryStore.shared.deleteCapture(screenshot, from: modelContext)
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

// MARK: - Tag Filter Chip
private struct TagFilterChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 9))
                Text(tag)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ScreenshotBrowserView()
        .modelContainer(for: Screenshot.self, inMemory: true)
        .frame(width: 800, height: 600)
}
