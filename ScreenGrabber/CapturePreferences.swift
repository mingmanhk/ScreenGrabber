//
//  CapturePreferences.swift
//  ScreenGrabber
//
//  Enhanced capture preferences and settings
//

import Foundation
import SwiftUI

// MARK: - Capture Delay Settings
struct CaptureDelaySettings {
    static let delays: [Int] = [0, 3, 5, 10]
    
    static var current: Int {
        get { UserDefaults.standard.integer(forKey: "captureDelay") }
        set { UserDefaults.standard.set(newValue, forKey: "captureDelay") }
    }
}

// MARK: - Image Compression Profile
enum CompressionProfile: String, CaseIterable, Codable {
    case highQualityPNG = "High Quality PNG"
    case compressedPNG = "Compressed PNG"
    case jpeg90 = "JPEG (High Quality)"
    case jpeg70 = "JPEG (Medium Quality)"
    case jpeg50 = "JPEG (Low Quality)"
    case heif = "HEIF"
    case webp = "WebP"
    
    var fileExtension: String {
        switch self {
        case .highQualityPNG, .compressedPNG:
            return "png"
        case .jpeg90, .jpeg70, .jpeg50:
            return "jpg"
        case .heif:
            return "heic"
        case .webp:
            return "webp"
        }
    }
    
    var quality: CGFloat {
        switch self {
        case .jpeg90: return 0.9
        case .jpeg70: return 0.7
        case .jpeg50: return 0.5
        default: return 1.0
        }
    }
    
    var icon: String {
        switch self {
        case .highQualityPNG: return "photo"
        case .compressedPNG: return "photo.fill"
        case .jpeg90, .jpeg70, .jpeg50: return "photo.on.rectangle"
        case .heif: return "photo.badge.checkmark"
        case .webp: return "globe"
        }
    }
    
    static var current: CompressionProfile {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: "compressionProfile"),
               let profile = CompressionProfile(rawValue: rawValue) {
                return profile
            }
            return .highQualityPNG
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "compressionProfile")
        }
    }
}

// MARK: - Region Preset
struct RegionPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var displayName: String?
    
    init(id: UUID = UUID(), name: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, displayName: String? = nil) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.displayName = displayName
    }
    
    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Region Presets Manager
class RegionPresetsManager: ObservableObject {
    static let shared = RegionPresetsManager()
    
    @Published var presets: [RegionPreset] = []
    
    private let presetsKey = "regionPresets"
    
    init() {
        loadPresets()
    }
    
    func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: presetsKey),
           let decoded = try? JSONDecoder().decode([RegionPreset].self, from: data) {
            presets = decoded
        }
    }
    
    func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: presetsKey)
        }
    }
    
    func addPreset(_ preset: RegionPreset) {
        presets.append(preset)
        savePresets()
    }
    
    func deletePreset(_ preset: RegionPreset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }
    
    func updatePreset(_ preset: RegionPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }
}

// MARK: - Auto-Copy Settings
enum AutoCopyOption: String, CaseIterable {
    case none = "None"
    case filename = "Filename"
    case filepath = "Full Path"
    case both = "Both"
    
    static var current: AutoCopyOption {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: "autoCopyOption"),
               let option = AutoCopyOption(rawValue: rawValue) {
                return option
            }
            return .none
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "autoCopyOption")
        }
    }
}

// MARK: - Smart Organization Rules
struct OrganizationRule: Codable, Identifiable {
    let id: UUID
    var enabled: Bool
    var ruleName: String
    var ruleType: RuleType
    var folderName: String
    
    enum RuleType: String, Codable {
        case wideScreenshot = "Width > Height"
        case smallSnippet = "Area < 800px"
        case fullScreen = "Full Screen"
        case windowCapture = "Window Capture"
        case sourceApp = "Source Application"
    }
    
    init(id: UUID = UUID(), enabled: Bool = true, ruleName: String, ruleType: RuleType, folderName: String) {
        self.id = id
        self.enabled = enabled
        self.ruleName = ruleName
        self.ruleType = ruleType
        self.folderName = folderName
    }
}

// MARK: - Organization Rules Manager
class OrganizationRulesManager: ObservableObject {
    static let shared = OrganizationRulesManager()
    
    @Published var rules: [OrganizationRule] = []
    
    private let rulesKey = "organizationRules"
    
    init() {
        loadRules()
        if rules.isEmpty {
            addDefaultRules()
        }
    }
    
    private func addDefaultRules() {
        rules = [
            OrganizationRule(ruleName: "Wide Screenshots", ruleType: .wideScreenshot, folderName: "Wide"),
            OrganizationRule(ruleName: "Small Snippets", ruleType: .smallSnippet, folderName: "Snippets"),
            OrganizationRule(ruleName: "Full Screens", ruleType: .fullScreen, folderName: "FullScreens"),
            OrganizationRule(ruleName: "Window Captures", ruleType: .windowCapture, folderName: "Windows")
        ]
        saveRules()
    }
    
    func loadRules() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([OrganizationRule].self, from: data) {
            rules = decoded
        }
    }
    
    func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: rulesKey)
        }
    }
    
    func determineFolder(for imageSize: CGSize, captureType: String) -> String? {
        for rule in rules where rule.enabled {
            switch rule.ruleType {
            case .wideScreenshot:
                if imageSize.width > imageSize.height {
                    return rule.folderName
                }
            case .smallSnippet:
                let area = imageSize.width * imageSize.height
                if area < 800 * 800 {
                    return rule.folderName
                }
            case .fullScreen:
                if captureType == "fullscreen" {
                    return rule.folderName
                }
            case .windowCapture:
                if captureType == "window" {
                    return rule.folderName
                }
            case .sourceApp:
                continue // Requires more context
            }
        }
        return nil
    }
}

// MARK: - Floating Thumbnail Settings
struct FloatingThumbnailSettings {
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "floatingThumbnailEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "floatingThumbnailEnabled") }
    }
    
    static var autoDismissDelay: Double {
        get {
            let value = UserDefaults.standard.double(forKey: "floatingThumbnailDelay")
            return value > 0 ? value : 5.0
        }
        set { UserDefaults.standard.set(newValue, forKey: "floatingThumbnailDelay") }
    }
}

// MARK: - Quick Actions Configuration
struct QuickAction: Identifiable, Codable {
    let id: UUID
    var name: String
    var icon: String
    var enabled: Bool
    var action: ActionType
    
    enum ActionType: String, Codable {
        case copyToClipboard
        case openInPreview
        case delete
        case share
        case annotate
        case pin
        case copyFilename
        case copyPath
        case showInFinder
    }
    
    init(id: UUID = UUID(), name: String, icon: String, enabled: Bool = true, action: ActionType) {
        self.id = id
        self.name = name
        self.icon = icon
        self.enabled = enabled
        self.action = action
    }
}

// MARK: - Quick Actions Manager
class QuickActionsManager: ObservableObject {
    static let shared = QuickActionsManager()
    
    @Published var actions: [QuickAction] = []
    
    private let actionsKey = "quickActions"
    
    init() {
        loadActions()
        if actions.isEmpty {
            addDefaultActions()
        }
    }
    
    private func addDefaultActions() {
        actions = [
            QuickAction(name: "Copy to Clipboard", icon: "doc.on.clipboard", action: .copyToClipboard),
            QuickAction(name: "Open in Preview", icon: "eye", action: .openInPreview),
            QuickAction(name: "Annotate", icon: "pencil.tip.crop.circle", action: .annotate),
            QuickAction(name: "Pin to Screen", icon: "pin", action: .pin),
            QuickAction(name: "Share", icon: "square.and.arrow.up", action: .share),
            QuickAction(name: "Delete", icon: "trash", action: .delete)
        ]
        saveActions()
    }
    
    func loadActions() {
        if let data = UserDefaults.standard.data(forKey: actionsKey),
           let decoded = try? JSONDecoder().decode([QuickAction].self, from: data) {
            actions = decoded
        }
    }
    
    func saveActions() {
        if let encoded = try? JSONEncoder().encode(actions) {
            UserDefaults.standard.set(encoded, forKey: actionsKey)
        }
    }
}

// MARK: - New Features Settings

struct NewFeaturesSettings {
    // Quick Draw
    static var quickDrawEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "quickDrawEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "quickDrawEnabled") }
    }

    static var quickDrawAutoShow: Bool {
        get { UserDefaults.standard.object(forKey: "quickDrawAutoShow") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "quickDrawAutoShow") }
    }

    // Smart Tags
    static var autoTaggingEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "autoTaggingEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoTaggingEnabled") }
    }

    // Project Workspaces
    static var autoDetectProject: Bool {
        get { UserDefaults.standard.object(forKey: "autoDetectProject") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoDetectProject") }
    }

    // Multi-Monitor
    static var rememberDisplayPreference: Bool {
        get { UserDefaults.standard.object(forKey: "rememberDisplayPreference") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "rememberDisplayPreference") }
    }

    // Auto-Trim
    static var autoTrimEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "autoTrimEnabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "autoTrimEnabled") }
    }
}
