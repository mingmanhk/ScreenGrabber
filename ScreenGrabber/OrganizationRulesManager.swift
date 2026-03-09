//
//  OrganizationRulesManager.swift
//  ScreenGrabber
//
//  Manages file organization rules for screenshots
//  Created on 11/13/25.
//

import Foundation
import AppKit
import Combine

@MainActor
class OrganizationRulesManager: ObservableObject {
    static let shared = OrganizationRulesManager()
    
    @Published var rules: [OrganizationRule] = []
    @Published var isEnabled = true
    
    private let rulesKey = "ScreenGrabber.OrganizationRules"
    
    private init() {
        loadRules()
    }
    
    // MARK: - Rule Management
    
    /// Adds a new organization rule
    func addRule(_ rule: OrganizationRule) {
        rules.append(rule)
        saveRules()
    }
    
    /// Removes a rule at the specified index
    func removeRule(at index: Int) {
        guard index >= 0 && index < rules.count else { return }
        rules.remove(at: index)
        saveRules()
    }
    
    /// Updates an existing rule
    func updateRule(at index: Int, with rule: OrganizationRule) {
        guard index >= 0 && index < rules.count else { return }
        rules[index] = rule
        saveRules()
    }
    
    /// Determines the destination folder based on active rules
    func destinationFolder(for screenshot: ScreenshotMetadata) -> URL? {
        guard isEnabled else { return nil }
        
        // Find the first matching rule
        for rule in rules where rule.isEnabled {
            if rule.matches(screenshot) {
                return rule.destinationURL
            }
        }
        
        return nil
    }
    
    // MARK: - Persistence
    
    private func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(encoded, forKey: rulesKey)
        }
    }
    
    private func loadRules() {
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([OrganizationRule].self, from: data) {
            rules = decoded
        } else {
            // Set up default rules
            rules = OrganizationRule.defaultRules
        }
    }
}

// MARK: - Organization Rule
struct OrganizationRule: Identifiable, Codable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var condition: RuleCondition
    var destinationPath: String
    
    var destinationURL: URL {
        URL(fileURLWithPath: (destinationPath as NSString).expandingTildeInPath)
    }
    
    init(id: UUID = UUID(), name: String, isEnabled: Bool = true, condition: RuleCondition, destinationPath: String) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.condition = condition
        self.destinationPath = destinationPath
    }
    
    /// Checks if this rule matches the given screenshot
    func matches(_ screenshot: ScreenshotMetadata) -> Bool {
        switch condition {
        case .captureMethod(let method):
            return screenshot.captureMethod == method
        case .application(let appName):
            return screenshot.activeApplication?.lowercased().contains(appName.lowercased()) ?? false
        case .dateRange(let start, let end):
            let hour = Calendar.current.component(.hour, from: screenshot.timestamp)
            return hour >= start && hour <= end
        case .fileSize(let comparison, let sizeMB):
            let fileSizeMB = Double(screenshot.fileSize) / (1024 * 1024)
            switch comparison {
            case .lessThan:
                return fileSizeMB < sizeMB
            case .greaterThan:
                return fileSizeMB > sizeMB
            case .equals:
                return abs(fileSizeMB - sizeMB) < 0.1
            }
        case .always:
            return true
        }
    }
    
    static var defaultRules: [OrganizationRule] {
        [
            OrganizationRule(
                name: "Full Screen Captures",
                condition: .captureMethod(.fullScreen),
                destinationPath: "~/Pictures/Screenshots/Full Screen"
            ),
            OrganizationRule(
                name: "Window Captures",
                condition: .captureMethod(.window),
                destinationPath: "~/Pictures/Screenshots/Windows"
            ),
            OrganizationRule(
                name: "Selected Area",
                condition: .captureMethod(.selectedArea),
                destinationPath: "~/Pictures/Screenshots/Selections"
            )
        ]
    }
}

// MARK: - Rule Condition
enum RuleCondition: Codable, Equatable {
    case captureMethod(ScreenOption)
    case application(String)
    case dateRange(start: Int, end: Int) // Hours in 24-hour format
    case fileSize(comparison: SizeComparison, sizeMB: Double)
    case always
    
    enum SizeComparison: String, Codable {
        case lessThan
        case greaterThan
        case equals
    }
    
    var displayName: String {
        switch self {
        case .captureMethod(let method):
            return "Capture Method: \(method.displayName)"
        case .application(let app):
            return "Application: \(app)"
        case .dateRange(let start, let end):
            return "Time: \(start):00 - \(end):00"
        case .fileSize(let comparison, let size):
            return "File Size: \(comparison.rawValue) \(size)MB"
        case .always:
            return "Always"
        }
    }
    
    // MARK: - Codable Implementation
    
    private enum CodingKeys: String, CodingKey {
        case type
        case screenOption
        case application
        case startHour
        case endHour
        case sizeComparison
        case sizeMB
    }
    
    private enum ConditionType: String, Codable {
        case captureMethod
        case application
        case dateRange
        case fileSize
        case always
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ConditionType.self, forKey: .type)
        
        switch type {
        case .captureMethod:
            let screenOptionRawValue = try container.decode(String.self, forKey: .screenOption)
            guard let screenOption = ScreenOption(rawValue: screenOptionRawValue) else {
                throw DecodingError.dataCorruptedError(forKey: .screenOption, in: container, debugDescription: "Invalid ScreenOption value")
            }
            self = .captureMethod(screenOption)
        case .application:
            let application = try container.decode(String.self, forKey: .application)
            self = .application(application)
        case .dateRange:
            let start = try container.decode(Int.self, forKey: .startHour)
            let end = try container.decode(Int.self, forKey: .endHour)
            self = .dateRange(start: start, end: end)
        case .fileSize:
            let comparison = try container.decode(SizeComparison.self, forKey: .sizeComparison)
            let sizeMB = try container.decode(Double.self, forKey: .sizeMB)
            self = .fileSize(comparison: comparison, sizeMB: sizeMB)
        case .always:
            self = .always
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .captureMethod(let screenOption):
            try container.encode(ConditionType.captureMethod, forKey: .type)
            try container.encode(screenOption.rawValue, forKey: .screenOption)
        case .application(let application):
            try container.encode(ConditionType.application, forKey: .type)
            try container.encode(application, forKey: .application)
        case .dateRange(let start, let end):
            try container.encode(ConditionType.dateRange, forKey: .type)
            try container.encode(start, forKey: .startHour)
            try container.encode(end, forKey: .endHour)
        case .fileSize(let comparison, let sizeMB):
            try container.encode(ConditionType.fileSize, forKey: .type)
            try container.encode(comparison, forKey: .sizeComparison)
            try container.encode(sizeMB, forKey: .sizeMB)
        case .always:
            try container.encode(ConditionType.always, forKey: .type)
        }
    }
}

// MARK: - Screenshot Metadata
struct ScreenshotMetadata {
    let timestamp: Date
    let captureMethod: ScreenOption
    let fileSize: Int64
    let activeApplication: String?
    
    init(timestamp: Date = Date(),
         captureMethod: ScreenOption = .selectedArea,
         fileSize: Int64 = 0,
         activeApplication: String? = nil) {
        self.timestamp = timestamp
        self.captureMethod = captureMethod
        self.fileSize = fileSize
        self.activeApplication = activeApplication ?? NSWorkspace.shared.frontmostApplication?.localizedName
    }
}
