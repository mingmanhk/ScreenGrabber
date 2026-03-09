//
//  MenuBarContentView.swift
//  ScreenGrabber
//
//  Menu bar popover: capture controls, recent captures list, and footer actions.
//

import SwiftUI
import SwiftData
import UserNotifications

struct MenuBarContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query private var items: [Item]

    @State private var showHotkeySheet = false
    @State private var currentHotkey = "⌘⇧C"
    @State private var recentScreenshots: [URL] = []
    @State private var hoveredCaptureURL: URL?
    @State private var showImageEditor = false
    @State private var imageURLToEdit: URL?
    @State private var reloadTask: Task<Void, Never>?

    @State private var settingsManager = SettingsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            captureOptionsSection
            Divider()
            recentCapturesSection
            Spacer(minLength: 0)
            footerSection
        }
        .frame(width: 360)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear(perform: loadSettings)
        .onReceive(NotificationCenter.default.publisher(for: .screenshotCaptured)) { _ in
            scheduleReload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .screenshotSavedToHistory)) { _ in
            scheduleReload()
        }
        .onReceive(NotificationCenter.default.publisher(for: ScreenshotMonitor.screenshotsChangedNotification)) { _ in
            scheduleReload()
        }
        .sheet(isPresented: $showHotkeySheet) {
            HotkeyConfigView(currentHotkey: $currentHotkey, onSave: setupGlobalHotkey)
        }
        .sheet(isPresented: $showImageEditor) {
            if let url = imageURLToEdit {
                ImageEditorContainer(imageURL: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestSettingsOpen)) { _ in
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 12) {
            appIcon
            appTitle
            Spacer()
            quickCaptureButton
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
    }

    private var appIcon: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var appTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Screen Grabber")
                .font(.system(size: 17, weight: .bold))
            Text("Capture & Edit")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var quickCaptureButton: some View {
        Button(action: quickCapture) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor)
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .shadow(color: .accentColor.opacity(0.4), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
        .help("Quick Capture (\(currentHotkey))")
    }

    // MARK: - Capture Options

    private var captureOptionsSection: some View {
        VStack(spacing: 16) {
            captureMethodGrid
            saveDestinationGrid
        }
        .padding(.vertical, 16)
    }

    private var captureMethodGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Capture Method", icon: "square.on.square.dashed", color: .accentColor)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(ScreenOption.allCases) { option in
                    OptionButton(
                        icon: option.icon,
                        label: option.displayName,
                        isSelected: settingsManager.selectedScreenOption == option
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            settingsManager.selectedScreenOption = option
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var saveDestinationGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("After Capture", icon: "arrow.down.doc", color: .purple)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(OpenOption.allCases) { option in
                    OptionButton(
                        icon: option.icon,
                        label: option.displayName,
                        isSelected: settingsManager.selectedOpenOption == option
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            settingsManager.selectedOpenOption = option
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func sectionLabel(_ title: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Recent Captures

    @ViewBuilder
    private var recentCapturesSection: some View {
        if recentScreenshots.isEmpty {
            emptyRecentCaptures
        } else {
            populatedRecentCaptures
        }
    }

    private var emptyRecentCaptures: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No Recent Captures")
                .font(.system(size: 14, weight: .semibold))
            Text("Press \(currentHotkey) to capture")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxHeight: 140)
    }

    private var populatedRecentCaptures: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "photo.stack")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Text("Recent Captures")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("\(min(recentScreenshots.count, 5))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Capsule().fill(Color.accentColor))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(recentScreenshots.prefix(5), id: \.self) { url in
                        RecentCaptureRow(
                            fileURL: url,
                            isHovered: hoveredCaptureURL == url,
                            onHover: { hoveredCaptureURL = $0 ? url : nil },
                            onEdit: { imageURLToEdit = url; showImageEditor = true }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 220)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                MenuActionButton(icon: "keyboard", label: currentHotkey, color: .accentColor) {
                    showHotkeySheet = true
                }
                MenuActionButton(icon: "square.grid.2x2", label: "Library", color: .purple) {
                    openWindow(id: "library")
                    NSApp.activate(ignoringOtherApps: true)
                }
                MenuActionButton(icon: "gearshape", label: "Settings", color: .gray) {
                    openWindow(id: "settings")
                    NSApp.activate(ignoringOtherApps: true)
                }
                MenuActionButton(icon: "power", label: "Quit", color: .red) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
    }
}

// MARK: - Action Helpers

extension MenuBarContentView {
    private func loadSettings() {
        currentHotkey = UserDefaults.standard.string(forKey: "grabScreenHotkey") ?? "⌘⇧C"
        loadRecentScreenshots()
        Task { @MainActor in
            if let folder = await UnifiedCaptureManager.shared.getCapturesFolderURL() {
                ScreenshotMonitor.shared.startMonitoring(url: folder)
            }
        }
    }

    /// Coalesces burst notifications (e.g. capture + monitor fire together) into one reload.
    private func scheduleReload() {
        reloadTask?.cancel()
        reloadTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            loadRecentScreenshots()
        }
    }

    private func loadRecentScreenshots() {
        let screenshots = UnifiedCaptureManager.shared.loadCaptureHistory(from: modelContext)
        recentScreenshots = screenshots.compactMap { URL(fileURLWithPath: $0.filePath) }

        Task { @MainActor in
            await CaptureHistoryStore.shared.loadRecentCaptures(from: modelContext)
            recentScreenshots = CaptureHistoryStore.shared.recentCaptures
                .compactMap { URL(fileURLWithPath: $0.filePath) }
        }
    }

    private func setupGlobalHotkey(hotkey: String) -> Bool {
        let ctx = ModelContext(ScreenGrabberApp.sharedModelContainer)
        let success = GlobalHotkeyManager.shared.registerHotkey(hotkey) {
            let settings = SettingsManager.shared
            DispatchQueue.main.async {
                ScreenCaptureManager.shared.captureScreen(
                    method: settings.selectedScreenOption,
                    openOption: settings.selectedOpenOption,
                    modelContext: ctx
                )
            }
        }
        if success {
            UserDefaults.standard.set(hotkey, forKey: "grabScreenHotkey")
            currentHotkey = hotkey
        }
        return success
    }

    private func quickCapture() {
        ScreenCaptureManager.shared.captureScreen(
            method: settingsManager.selectedScreenOption,
            openOption: settingsManager.selectedOpenOption,
            modelContext: modelContext
        )
    }
}

// MARK: - Recent Capture Row

extension MenuBarContentView {
    struct RecentCaptureRow: View {
        let fileURL: URL
        let isHovered: Bool
        let onHover: (Bool) -> Void
        let onEdit: () -> Void

        @State private var fileDate: String = ""

        var body: some View {
            HStack(spacing: 12) {
                // Thumbnail — uses shared cache, no lockFocus on bg thread
                AsyncThumbnail(url: fileURL, maxPixelSize: 160, contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isHovered ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.1),
                                lineWidth: isHovered ? 2 : 1
                            )
                    )

                // File info
                VStack(alignment: .leading, spacing: 4) {
                    Text(fileURL.lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "clock").font(.system(size: 9)).foregroundColor(.secondary)
                        Text(fileDate).font(.system(size: 10)).foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 4)

                if isHovered {
                    HStack(spacing: 6) {
                        Button(action: onEdit) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                        .help("Edit Image")

                        Button(action: { NSWorkspace.shared.open(fileURL) }) {
                            Image(systemName: "eye.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                        .help("Preview")
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered
                          ? Color.accentColor.opacity(0.08)
                          : Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        isHovered ? Color.accentColor.opacity(0.25) : Color.clear,
                        lineWidth: 1
                    )
            )
            .onHover { hovering in withAnimation(.easeInOut(duration: 0.2)) { onHover(hovering) } }
            .task(id: fileURL) { fileDate = await resolveRelativeDate(fileURL) }
            .contextMenu {
                Button("Open") { NSWorkspace.shared.open(fileURL) }
                Button("Edit in Image Editor") { onEdit() }
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(
                        fileURL.path,
                        inFileViewerRootedAtPath: fileURL.deletingLastPathComponent().path
                    )
                }
                Divider()
                Button("Copy to Clipboard") {
                    if let image = NSImage(contentsOf: fileURL) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.writeObjects([image])
                    }
                }
                Divider()
                Button("Delete", role: .destructive) {
                    ThumbnailCache.shared.invalidate(url: fileURL)
                    try? FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
                }
            }
        }

        private func resolveRelativeDate(_ url: URL) async -> String {
            await Task.detached(priority: .background) {
                guard let vals = try? url.resourceValues(forKeys: [.creationDateKey]),
                      let date = vals.creationDate else { return "Unknown" }
                let fmt = RelativeDateTimeFormatter()
                fmt.unitsStyle = .abbreviated
                return fmt.localizedString(for: date, relativeTo: Date())
            }.value
        }
    }

    // MARK: - Hotkey Config Sheet

    struct HotkeyConfigView: View {
        @Binding var currentHotkey: String
        let onSave: (String) -> Bool
        @Environment(\.dismiss) private var dismiss
        @State private var newHotkey: String
        @State private var errorMessage: String?

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

                TextField("e.g. ⌘⇧C", text: $newHotkey)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .font(.title3)

                if let msg = errorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                HStack {
                    Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                    Button("Save") {
                        if onSave(newHotkey) { dismiss() }
                        else { errorMessage = "This hotkey is already in use. Please try another." }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newHotkey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(24)
            .frame(width: 350)
        }
    }
}

#Preview {
    MenuBarContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
