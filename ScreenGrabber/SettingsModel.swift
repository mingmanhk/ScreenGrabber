//
//  SettingsModel.swift
//  ScreenGrabber
//
//  Central settings store for the application
//

import Foundation
import SwiftUI
import Combine

/// Central settings model for ScreenGrabber
@MainActor
class SettingsModel: ObservableObject {
    static let shared = SettingsModel()
    
    // MARK: - General Settings
    
    @AppStorage("keepInMenuBar") var keepInMenuBar: Bool = true
    @AppStorage("autoUpdateFrequency") var autoUpdateFrequencyRaw: String = "daily"
    @AppStorage("sendCrashReports") var sendCrashReports: Bool = true
    @AppStorage("showTips") var showTips: Bool = true
    
    var autoUpdateFrequency: AutoUpdateFrequency {
        get { AutoUpdateFrequency(rawValue: autoUpdateFrequencyRaw) ?? .daily }
        set { autoUpdateFrequencyRaw = newValue.rawValue }
    }
    
    // MARK: - Capture Settings
    
    @AppStorage("captureFormat") var captureFormat: ImageFormat = .png
    @AppStorage("captureQuality") var captureQuality: Double = 1.0
    @AppStorage("includeCursor") var includeCursor: Bool = false
    @AppStorage("captureDelay") var captureDelay: Double = 0.0
    @AppStorage("captureSound") var captureSound: Bool = true
    
    // MARK: - Capture Options (for UI toggles)
    
    @AppStorage("copyToClipboardEnabled") var copyToClipboardEnabled: Bool = false
    @AppStorage("previewInEditorEnabled") var previewInEditorEnabled: Bool = false
    @AppStorage("timeDelayEnabled") var timeDelayEnabled: Bool = false
    @AppStorage("timeDelaySeconds") var timeDelaySeconds: Double = 3.0
    
    // MARK: - Save Location
    
    @AppStorage("customScreenshotLocation") var customSaveLocationPath: String?
    
    var saveFolderPath: String {
        get { customSaveLocationPath ?? "" }
        set { customSaveLocationPath = newValue.isEmpty ? nil : newValue }
    }
    
    /// Returns the effective save URL with validation
    var effectiveSaveURL: URL {
        // Try custom location first
        if let customPath = customSaveLocationPath,
           !customPath.isEmpty {
            let customURL = URL(fileURLWithPath: customPath)
            
            // Validate that custom location still exists and is accessible
            if FileManager.default.fileExists(atPath: customURL.path) {
                return customURL
            } else {
                CaptureLogger.log(.error, "Custom save location no longer exists: \(customPath) — reverting to default")
                customSaveLocationPath = nil
            }
        }
        
        // Default to ~/Pictures/Screen Grabber
        let picturesURL = FileManager.default.urls(
            for: .picturesDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        
        return picturesURL.appendingPathComponent("Screen Grabber")
    }
    
    /// Validates that the save URL exists and is writable
    func validateSaveLocation() -> Bool {
        let url = effectiveSaveURL
        
        // Check if directory exists
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        
        guard exists && isDir.boolValue else {
            CaptureLogger.log(.error, "Save location does not exist: \(url.path)")
            return false
        }

        // Check if writable
        let testFile = url.appendingPathComponent(".screengrabber_write_test")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            CaptureLogger.log(.debug, "Save location valid and writable: \(url.path)")
            return true
        } catch {
            CaptureLogger.log(.error, "Save location not writable: \(error.localizedDescription)")
            return false
        }
    }
    
    func setCustomSaveLocation(_ url: URL) {
        CaptureLogger.log(.save, "Custom save location set: \(url.path)")
        customSaveLocationPath = url.path
    }

    /// Resets save location to default (~/Pictures/Screen Grabber).
    func resetSaveLocationToDefault() {
        CaptureLogger.log(.save, "Save location reset to default")
        customSaveLocationPath = nil
    }
    
    // MARK: - File Naming
    
    @AppStorage("filenameTemplate") var filenameTemplate: String = "Screenshot_{timestamp}"
    @AppStorage("useSmartNaming") var useSmartNaming: Bool = false
    
    // MARK: - Video Settings
    
    @AppStorage("frameRate") var frameRateRaw: String = "30"
    @AppStorage("encoding") var encodingRaw: String = "H264"
    @AppStorage("downsampleRetina") var downsampleRetina: Bool = false
    @AppStorage("showVideoCountdown") var showVideoCountdown: Bool = true
    
    var frameRate: FrameRate {
        get { FrameRate(rawValue: frameRateRaw) ?? .fps30 }
        set { frameRateRaw = newValue.rawValue }
    }
    
    var encoding: Encoding {
        get { Encoding(rawValue: encodingRaw) ?? .h264 }
        set { encodingRaw = newValue.rawValue }
    }
    
    // MARK: - Audio Settings
    
    @AppStorage("combineAudioTracks") var combineAudioTracks: Bool = false
    @AppStorage("systemAudio") var systemAudioRaw: String = "Default"
    
    var systemAudio: SystemAudioSource {
        get { SystemAudioSource(rawValue: systemAudioRaw) ?? .default }
        set { systemAudioRaw = newValue.rawValue }
    }
    
    // MARK: - Floating Thumbnail
    
    @Published var floatingThumbnailSettings: FloatingThumbnailSettings = .default
    
    private let thumbnailSettingsKey = "floatingThumbnailSettings"
    
    // MARK: - OCR Settings
    
    @AppStorage("ocrEnabled") var ocrEnabled: Bool = true
    @AppStorage("autoCopyOCRText") var autoCopyOCRText: Bool = false
    @AppStorage("ocrLanguages") var ocrLanguagesString: String = "en-US"
    
    var ocrLanguages: [String] {
        get { ocrLanguagesString.components(separatedBy: ",") }
        set { ocrLanguagesString = newValue.joined(separator: ",") }
    }
    
    // MARK: - Editor Settings
    
    @AppStorage("defaultAnnotationColor") var defaultAnnotationColor: String = "FF0000"
    @AppStorage("defaultLineWidth") var defaultLineWidth: Double = 3.0
    @AppStorage("defaultFontSize") var defaultFontSize: Double = 16.0
    @AppStorage("showGrid") var showGrid: Bool = false
    @AppStorage("gridSize") var gridSize: Double = 20.0
    
    // MARK: - Auto-Save & Backup
    
    @AppStorage("autoSaveEnabled") var autoSaveEnabled: Bool = true
    @AppStorage("autoSaveInterval") var autoSaveInterval: Double = 60.0
    @AppStorage("keepBackups") var keepBackups: Bool = true
    @AppStorage("maxBackups") var maxBackups: Int = 10
    
    // MARK: - Privacy & Security
    
    @AppStorage("autoRedactSensitiveInfo") var autoRedactSensitiveInfo: Bool = false
    @AppStorage("blurScreenshotsInHistory") var blurScreenshotsInHistory: Bool = false
    
    // MARK: - Compression Profiles
    
    @AppStorage("selectedCompressionProfile") var selectedCompressionProfileRaw: String = "high"
    
    var selectedCompressionProfile: CompressionProfile {
        get {
            CompressionProfile(rawValue: selectedCompressionProfileRaw) ?? .high
        }
        set {
            selectedCompressionProfileRaw = newValue.rawValue
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        loadFloatingThumbnailSettings()
    }
    
    // MARK: - Persistence Helpers
    
    private func loadFloatingThumbnailSettings() {
        if let data = UserDefaults.standard.data(forKey: thumbnailSettingsKey),
           let settings = try? JSONDecoder().decode(FloatingThumbnailSettings.self, from: data) {
            floatingThumbnailSettings = settings
        }
    }
    
    func saveFloatingThumbnailSettings() {
        if let data = try? JSONEncoder().encode(floatingThumbnailSettings) {
            UserDefaults.standard.set(data, forKey: thumbnailSettingsKey)
        }
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        captureFormat = .png
        captureQuality = 1.0
        includeCursor = false
        captureDelay = 0.0
        captureSound = true
        
        customSaveLocationPath = nil
        filenameTemplate = "Screenshot_{timestamp}"
        useSmartNaming = false
        
        floatingThumbnailSettings = .default
        saveFloatingThumbnailSettings()
        
        ocrEnabled = true
        autoCopyOCRText = false
        ocrLanguagesString = "en-US"
        
        defaultAnnotationColor = "FF0000"
        defaultLineWidth = 3.0
        defaultFontSize = 16.0
        showGrid = false
        gridSize = 20.0
        
        autoSaveEnabled = true
        autoSaveInterval = 60.0
        keepBackups = true
        maxBackups = 10
        
        autoRedactSensitiveInfo = false
        blurScreenshotsInHistory = false
        
        selectedCompressionProfile = .high
    }
}

// MARK: - Supporting Types

enum ImageFormat: String, Codable, CaseIterable {
    case png = "PNG"
    case jpeg = "JPEG"
    case heic = "HEIC"
    case tiff = "TIFF"
    
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .heic: return "heic"
        case .tiff: return "tiff"
        }
    }
    
    var displayName: String {
        rawValue
    }
}

// MARK: - SettingsModel Extensions

extension SettingsModel {
    
    enum AutoUpdateFrequency: String, CaseIterable, Identifiable {
        case never = "never"
        case daily = "daily"
        case weekly = "weekly"
        case monthly = "monthly"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .never: return "Never"
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            }
        }
    }
    
    enum FrameRate: String, CaseIterable, Identifiable {
        case fps24 = "24"
        case fps30 = "30"
        case fps60 = "60"
        case fps120 = "120"
        
        var id: String { rawValue }
        
        var displayName: String {
            "\(rawValue) fps"
        }
        
        var value: Int {
            Int(rawValue) ?? 30
        }
    }
    
    enum Encoding: String, CaseIterable, Identifiable {
        case h264 = "H264"
        case hevc = "HEVC"
        case prores = "ProRes"
        
        var id: String { rawValue }
        
        var displayName: String { rawValue }
    }
    
    enum SystemAudioSource: String, CaseIterable, Identifiable {
        case `default` = "Default"
        case none = "None"
        case all = "All"
        
        var id: String { rawValue }
        
        var displayName: String { rawValue }
    }
}

// CompressionProfile is now defined in CaptureSettings.swift
// The enum-based version is used instead of the struct-based version

