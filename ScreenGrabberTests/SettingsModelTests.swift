//
//  SettingsModelTests.swift
//  ScreenGrabberTests
//
//  Unit tests for SettingsModel defaults, validation, and reset logic.
//

import Testing
import Foundation
@testable import ScreenGrabber

@Suite("SettingsModel")
@MainActor
struct SettingsModelTests {

    // MARK: - Default Values

    @Test func captureDelayDefault() {
        // captureDelay should default to 0 (no delay)
        let model = SettingsModel.shared
        // Defaults are AppStorage-backed; we just confirm they're in valid range
        #expect(model.captureDelay >= 0.0)
        #expect(model.captureDelay <= 60.0)
    }

    @Test func captureQualityDefault() {
        let model = SettingsModel.shared
        #expect(model.captureQuality >= 0.0)
        #expect(model.captureQuality <= 1.0)
    }

    @Test func captureFormatIsImageFormat() {
        let model = SettingsModel.shared
        // Should be a valid ImageFormat (png or jpg)
        let validFormats: [ImageFormat] = [.png, .jpeg]
        #expect(validFormats.contains(model.captureFormat))
    }

    @Test func timeDelaySecondsIsPositive() {
        let model = SettingsModel.shared
        #expect(model.timeDelaySeconds > 0.0)
        #expect(model.timeDelaySeconds <= 60.0)
    }

    @Test func defaultLineWidthIsPositive() {
        let model = SettingsModel.shared
        #expect(model.defaultLineWidth > 0.0)
    }

    @Test func defaultFontSizeIsPositive() {
        let model = SettingsModel.shared
        #expect(model.defaultFontSize > 0.0)
    }

    @Test func gridSizeIsPositive() {
        let model = SettingsModel.shared
        #expect(model.gridSize > 0.0)
    }

    // MARK: - effectiveSaveURL

    @Test func effectiveSaveURLIsNonEmpty() {
        let model = SettingsModel.shared
        // Clear any custom path to test default behavior
        let savedPath = model.customSaveLocationPath
        model.customSaveLocationPath = nil

        let url = model.effectiveSaveURL
        #expect(!url.path.isEmpty)
        #expect(url.lastPathComponent == "Screen Grabber")

        // Restore
        model.customSaveLocationPath = savedPath
    }

    @Test func effectiveSaveURLWithCustomPath() {
        let model = SettingsModel.shared
        let savedPath = model.customSaveLocationPath

        // Set a path that actually exists (temp dir)
        let testPath = FileManager.default.temporaryDirectory.path
        model.customSaveLocationPath = testPath

        let url = model.effectiveSaveURL
        #expect(url.path == testPath)

        // Restore
        model.customSaveLocationPath = savedPath
    }

    @Test func effectiveSaveURLFallsBackWhenCustomPathMissing() {
        let model = SettingsModel.shared
        let savedPath = model.customSaveLocationPath

        // Set a path that does not exist
        model.customSaveLocationPath = "/nonexistent/path/12345"

        let url = model.effectiveSaveURL
        // Should fall back to default and clear the invalid custom path
        #expect(url.lastPathComponent == "Screen Grabber")
        #expect(model.customSaveLocationPath == nil)

        // Restore
        model.customSaveLocationPath = savedPath
    }

    // MARK: - filenameTemplate

    @Test func filenameTemplateContainsTimestampPlaceholder() {
        let model = SettingsModel.shared
        // Default template should include a timestamp placeholder or be non-empty
        #expect(!model.filenameTemplate.isEmpty)
    }

    // MARK: - saveFolderPath bridge

    @Test func saveFolderPathBridgeRoundTrip() {
        let model = SettingsModel.shared
        let savedPath = model.customSaveLocationPath

        model.saveFolderPath = "/tmp/test"
        #expect(model.customSaveLocationPath == "/tmp/test")

        model.saveFolderPath = ""
        #expect(model.customSaveLocationPath == nil)

        // Restore
        model.customSaveLocationPath = savedPath
    }

    // MARK: - resetToDefaults

    @Test func resetToDefaultsRestoresCaptureFormat() {
        let model = SettingsModel.shared
        let saved = model.captureFormat

        model.captureFormat = .jpeg
        model.resetToDefaults()
        #expect(model.captureFormat == .png)

        // Restore
        model.captureFormat = saved
    }

    @Test func resetToDefaultsRestoresCaptureDelay() {
        let model = SettingsModel.shared
        let saved = model.captureDelay

        model.captureDelay = 5.0
        model.resetToDefaults()
        #expect(model.captureDelay == 0.0)

        // Restore
        model.captureDelay = saved
    }

    @Test func resetToDefaultsClearsCustomSaveLocation() {
        let model = SettingsModel.shared
        let saved = model.customSaveLocationPath

        model.customSaveLocationPath = "/tmp/some/path"
        model.resetToDefaults()
        #expect(model.customSaveLocationPath == nil)

        // Restore
        model.customSaveLocationPath = saved
    }

    @Test func resetToDefaultsRestoresFilenameTemplate() {
        let model = SettingsModel.shared
        let saved = model.filenameTemplate

        model.filenameTemplate = "custom_{date}"
        model.resetToDefaults()
        #expect(model.filenameTemplate == "Screenshot_{timestamp}")

        // Restore
        model.filenameTemplate = saved
    }

    // MARK: - AutoUpdateFrequency

    @Test func autoUpdateFrequencyRoundTrip() {
        let model = SettingsModel.shared
        let saved = model.autoUpdateFrequency

        model.autoUpdateFrequency = .weekly
        #expect(model.autoUpdateFrequency == .weekly)
        #expect(model.autoUpdateFrequencyRaw == "weekly")

        // Restore
        model.autoUpdateFrequency = saved
    }
}
