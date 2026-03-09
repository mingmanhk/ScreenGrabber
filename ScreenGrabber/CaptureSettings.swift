//
//  CaptureSettings.swift
//  ScreenGrabber
//
//  Additional settings types for capture functionality
//

import Foundation
import Combine

// MARK: - Capture Preset

struct CapturePreset: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String

    var captureType: String         // ScreenOption rawValue
    var copyToClipboard: Bool
    var previewInEditor: Bool
    var includeCursor: Bool
    var timeDelayEnabled: Bool
    var timeDelaySeconds: Double

    static let defaultPresets: [CapturePreset] = [
        CapturePreset(
            name: "Quick Capture",
            captureType: ScreenOption.selectedArea.rawValue,
            copyToClipboard: true,
            previewInEditor: false,
            includeCursor: false,
            timeDelayEnabled: false,
            timeDelaySeconds: 3
        ),
        CapturePreset(
            name: "Full Screen + Editor",
            captureType: ScreenOption.fullScreen.rawValue,
            copyToClipboard: false,
            previewInEditor: true,
            includeCursor: false,
            timeDelayEnabled: false,
            timeDelaySeconds: 3
        ),
        CapturePreset(
            name: "Delayed (5s)",
            captureType: ScreenOption.selectedArea.rawValue,
            copyToClipboard: false,
            previewInEditor: false,
            includeCursor: true,
            timeDelayEnabled: true,
            timeDelaySeconds: 5
        )
    ]
}

// MARK: - Capture Preset Manager

final class CapturePresetManager: ObservableObject {
    static let shared = CapturePresetManager()

    @Published private(set) var presets: [CapturePreset] = []

    private let defaultsKey = "capturePresets"

    private init() {
        load()
        if presets.isEmpty {
            presets = CapturePreset.defaultPresets
            save()
        }
    }

    func add(_ preset: CapturePreset) {
        presets.append(preset)
        save()
    }

    func update(_ preset: CapturePreset) {
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[idx] = preset
            save()
        }
    }

    func delete(_ preset: CapturePreset) {
        presets.removeAll { $0.id == preset.id }
        save()
    }

    func apply(_ preset: CapturePreset, settings: SettingsManager, model: SettingsModel) {
        if let option = ScreenOption(rawValue: preset.captureType) {
            settings.selectedScreenOption = option
        }
        model.copyToClipboardEnabled = preset.copyToClipboard
        model.previewInEditorEnabled = preset.previewInEditor
        model.includeCursor = preset.includeCursor
        model.timeDelayEnabled = preset.timeDelayEnabled
        model.timeDelaySeconds = preset.timeDelaySeconds
    }

    func save() {
        if let data = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([CapturePreset].self, from: data) else { return }
        presets = decoded
    }
}



/// Auto-copy behavior after capture
enum AutoCopyOption: String, CaseIterable, Identifiable, Codable {
    case never = "Never"
    case always = "Always"
    case ask = "Ask Each Time"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
}

/// Compression profile for saved images
enum CompressionProfile: String, CaseIterable, Identifiable, Codable {
    case none = "None (Uncompressed)"
    case low = "Low Quality"
    case medium = "Medium Quality"
    case high = "High Quality"
    case maximum = "Maximum Quality"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
    
    var compressionQuality: CGFloat {
        switch self {
        case .none: return 1.0
        case .low: return 0.5
        case .medium: return 0.7
        case .high: return 0.85
        case .maximum: return 0.95
        }
    }
}
