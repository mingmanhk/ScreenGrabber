//
//  ContentView.swift
//  ScreenGrabber
//
//  Main library window — split layout with capture panel, screenshot grid, and bottom strip.
//

import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var recentScreenshots: [URL] = []
    @State private var editorURL: IdentifiableURL?
    @StateObject private var settingsManager = SettingsManager.shared
    @ObservedObject private var settingsModel = SettingsModel.shared

    // Countdown
    @State private var showingCountdown = false
    @State private var countdownValue = 0
    @State private var countdownTask: Task<Void, Never>?

    // Debounce reloads to prevent notification storms
    @State private var reloadTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    CapturePanel(
                        settingsManager: settingsManager,
                        onCapture: captureScreen,
                        onOpenEditor: {
                            if let recent = recentScreenshots.first { openEditor(for: recent) }
                        }
                    )
                    .frame(width: 300)

                    Divider()

                    libraryPanel
                }

                Divider()

                BottomCapturesStrip(
                    recentScreenshots: recentScreenshots,
                    onEdit: { openEditor(for: $0) },
                    onRefresh: loadRecentScreenshots
                )
            }
            .frame(minWidth: 1000, minHeight: 600)

            if showingCountdown {
                CaptureCountdownOverlay(countdown: countdownValue, onCancel: cancelCountdown)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: showingCountdown)
            }
        }
        .sheet(item: $editorURL) { item in
            ScreenCaptureEditorView(fileURL: item.url)
                .frame(minWidth: 900, minHeight: 600)
        }
        .onAppear {
            setupMonitor()
            loadRecentScreenshots()
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenshotCaptured)) { _ in
            scheduleReload()
        }
        .onReceive(NotificationCenter.default.publisher(for: ScreenshotMonitor.screenshotsChangedNotification)) { _ in
            scheduleReload()
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var libraryPanel: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)

            if recentScreenshots.isEmpty {
                EmptyLibraryStateView()
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)],
                        spacing: 20
                    ) {
                        ForEach(recentScreenshots, id: \.self) { url in
                            ScreenshotCard(fileURL: url, onOpen: { openEditor(for: url) })
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func openEditor(for url: URL) {
        editorURL = IdentifiableURL(url)
    }

    private func captureScreen() {
        if settingsModel.timeDelayEnabled && settingsModel.timeDelaySeconds > 0 {
            startCountdown(seconds: Int(settingsModel.timeDelaySeconds))
        } else {
            performCapture()
        }
    }

    private func performCapture() {
        ScreenCaptureManager.shared.captureScreen(
            method: settingsManager.selectedScreenOption,
            openOption: settingsManager.selectedOpenOption,
            modelContext: modelContext
        )
    }

    private func startCountdown(seconds: Int) {
        countdownValue = seconds
        withAnimation { showingCountdown = true }
        countdownTask = Task { @MainActor in
            for remaining in stride(from: seconds, through: 1, by: -1) {
                guard !Task.isCancelled else { return }
                countdownValue = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            guard !Task.isCancelled else { return }
            withAnimation { showingCountdown = false }
            try? await Task.sleep(nanoseconds: 100_000_000)
            performCapture()
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        withAnimation { showingCountdown = false }
    }

    /// Debounces rapid successive reload requests (e.g. two notifications fired by a single capture).
    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 s debounce
            guard !Task.isCancelled else { return }
            loadRecentScreenshots()
        }
    }

    private func loadRecentScreenshots() {
        Task {
            guard let folder = await UnifiedCaptureManager.shared.getCapturesFolderURL() else {
                await MainActor.run { self.recentScreenshots = [] }
                return
            }

            let sorted = await Task.detached(priority: .userInitiated) {
                // includingPropertiesForKeys pre-fetches dates — no extra I/O per file
                let files = (try? FileManager.default.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )) ?? []
                return files
                    .filter { ["png", "jpg", "jpeg"].contains($0.pathExtension.lowercased()) }
                    .sorted {
                        let d1 = (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                        let d2 = (try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                        return d1 > d2
                    }
            }.value

            await MainActor.run { self.recentScreenshots = sorted }
        }
    }

    private func setupMonitor() {
        Task { @MainActor in
            if let folderURL = await UnifiedCaptureManager.shared.getCapturesFolderURL() {
                ScreenshotMonitor.shared.startMonitoring(url: folderURL)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyLibraryStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundStyle(.tertiary)

            Text("No Screenshots Yet")
                .font(.title2)
                .fontWeight(.medium)

            Text("Captured images will appear here")
                .foregroundColor(.secondary)

            ShortcutBadge(keys: ["⌘", "⇧", "1"], label: "Capture")
                .padding(.top, 10)
        }
    }
}

struct ShortcutBadge: View {
    let keys: [String]
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }
}

// MARK: - Screenshot Card

struct ScreenshotCard: View {
    let fileURL: URL
    let onOpen: () -> Void

    @State private var isHovering = false
    @State private var fileDate: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailArea
            Divider()
            footer
        }
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onHover { hovering in withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering } }
        .onTapGesture { onOpen() }
        .task(id: fileURL) { fileDate = await resolveFileDate(fileURL) }
    }

    private var thumbnailArea: some View {
        ZStack {
            Color.black.opacity(0.05)

            AsyncThumbnail(url: fileURL, maxPixelSize: 440, contentMode: .fit)
                .padding(8)

            if isHovering {
                Color.black.opacity(0.3)
                Button("Edit") { onOpen() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
        }
        .frame(height: 130)
        .clipped()
    }

    private var footer: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(fileURL.lastPathComponent)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(fileDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    /// Resolves the file creation date off the main thread.
    private func resolveFileDate(_ url: URL) async -> String {
        await Task.detached(priority: .background) {
            guard let vals = try? url.resourceValues(forKeys: [.creationDateKey]),
                  let date = vals.creationDate else { return "" }
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            fmt.timeStyle = .short
            return fmt.string(from: date)
        }.value
    }
}

// MARK: - Capture Countdown Overlay

struct CaptureCountdownOverlay: View {
    let countdown: Int
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 28) {
                Text("\(countdown)")
                    .font(.system(size: 140, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.easeInOut(duration: 0.4), value: countdown)
                    .shadow(color: .black.opacity(0.4), radius: 20)

                Text("Capture starts in \(countdown) second\(countdown == 1 ? "" : "s")…")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.85))

                Button(action: onCancel) {
                    Label("Cancel", systemImage: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(20)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}

/// Thin Identifiable wrapper around URL so we can use .sheet(item:).
struct IdentifiableURL: Identifiable {
    let id: String
    let url: URL
    init(_ url: URL) { self.id = url.absoluteString; self.url = url }
}
