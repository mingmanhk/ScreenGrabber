//
//  ScreenCaptureManager+NewFeatures.swift
//  ScreenGrabber
//
//  Extension to integrate new features into ScreenCaptureManager
//

import Foundation
import AppKit
import SwiftData

extension ScreenCaptureManager {

    // MARK: - Enhanced Capture with New Features

    /// Capture screen with all new features integrated
    func captureScreenEnhanced(
        method: CaptureMethod = .selectedArea,
        outputOption: OutputOption = .clipboard,
        modelContext: ModelContext?,
        completion: ((Bool, String?) -> Void)? = nil
    ) {
        // Get selected display
        let displayManager = MultiMonitorManager.shared
        let selectedDisplay = displayManager.selectedDisplay

        // Build capture arguments
        var captureArgs = buildCaptureArguments(
            method: method,
            outputOption: outputOption,
            display: selectedDisplay
        )

        // Execute capture
        let timestamp = Date()
        let filename = generateFilename(timestamp: timestamp)
        let savePath = getSavePath(filename: filename)

        print("[CAPTURE] Starting enhanced capture: \(method.rawValue)")
        print("[CAPTURE] Display: \(selectedDisplay?.name ?? "Default")")
        print("[CAPTURE] Save path: \(savePath)")

        // Add path to arguments
        captureArgs.append(savePath)

        executeCapture(arguments: captureArgs) { [weak self] success in
            guard let self = self else { return }

            if success {
                self.postProcessCapture(
                    filePath: savePath,
                    filename: filename,
                    captureDate: timestamp,
                    captureMethod: method.rawValue,
                    openMethod: outputOption.rawValue,
                    displayInfo: selectedDisplay,
                    modelContext: modelContext,
                    completion: completion
                )
            } else {
                completion?(false, nil)
            }
        }
    }

    // MARK: - Build Capture Arguments

    private func buildCaptureArguments(
        method: CaptureMethod,
        outputOption: OutputOption,
        display: MultiMonitorManager.Display?
    ) -> [String] {
        var args: [String] = []

        // Add display selection if specified
        if let display = display {
            args.append("-D")
            args.append(display.id)
        }

        // Add capture method arguments
        switch method {
        case .selectedArea:
            args.append("-i")
        case .window:
            args.append("-w")
        case .fullScreen:
            // No additional args needed
            break
        case .scrollingCapture:
            args.append("-i") // Fallback to interactive
            break
        }

        // Add delay if configured
        let delay = CaptureDelaySettings.current
        if delay > 0 {
            args.append("-T")
            args.append("\(delay)")
        }

        return args
    }

    // MARK: - Post-Processing

    private func postProcessCapture(
        filePath: String,
        filename: String,
        captureDate: Date,
        captureMethod: String,
        openMethod: String,
        displayInfo: MultiMonitorManager.Display?,
        modelContext: ModelContext?,
        completion: ((Bool, String?) -> Void)?
    ) {
        guard let image = NSImage(contentsOfFile: filePath) else {
            print("[ERROR] Failed to load captured image")
            completion?(false, nil)
            return
        }

        var processedImage = image
        var wasTrimmed = false
        var originalSize = image.size

        // 1. Auto-Trim
        let trimManager = AutoTrimManager.shared
        if trimManager.autoTrimEnabled {
            let result = trimManager.trimImage(image)
            processedImage = result.image
            wasTrimmed = result.wasTrimmed
            originalSize = result.originalSize

            if wasTrimmed {
                print("[AUTO-TRIM] Image trimmed from \(originalSize) to \(processedImage.size)")
            }
        }

        // Save processed image if modified
        if wasTrimmed {
            saveImage(processedImage, to: filePath)
        }

        // 2. Generate Smart Tags
        let tagsManager = SmartTagsManager.shared
        let autoTags = tagsManager.generateAutoTags(
            for: processedImage,
            captureMethod: captureMethod,
            filename: filename
        )

        // 3. Detect Project
        let projectManager = ProjectWorkspaceManager.shared
        let extractedText = extractTextForAnalysis(from: processedImage)
        let detectedProject = projectManager.detectProject(
            from: extractedText,
            windowTitle: nil
        )

        let projectName = detectedProject?.name ?? projectManager.activeProject?.name

        // 4. Create Screenshot Record
        let screenshot = Screenshot(
            filename: filename,
            filePath: filePath,
            captureDate: captureDate,
            captureMethod: captureMethod,
            openMethod: openMethod,
            tags: [],
            autoTags: autoTags,
            projectName: projectName,
            displayID: displayInfo?.id,
            displayName: displayInfo?.name,
            isAutoTrimmed: wasTrimmed,
            originalDimensions: wasTrimmed ? "\(Int(originalSize.width))x\(Int(originalSize.height))" : nil
        )

        // Save to database
        if let context = modelContext {
            context.insert(screenshot)
            try? context.save()
        }

        // Update project statistics
        if let project = detectedProject ?? projectManager.activeProject {
            projectManager.incrementScreenshotCount(for: project)
        }

        // 5. Quick Draw
        let quickDrawManager = QuickDrawManager.shared
        if quickDrawManager.isQuickDrawEnabled && NewFeaturesSettings.quickDrawAutoShow {
            DispatchQueue.main.async {
                quickDrawManager.showQuickDraw(for: processedImage)
            }
        }

        // 6. Show notification
        showEnhancedNotification(
            filename: filename,
            projectName: projectName,
            tags: autoTags,
            wasTrimmed: wasTrimmed
        )

        print("[CAPTURE] Enhanced capture completed successfully")
        print("[TAGS] Auto-generated tags: \(autoTags.joined(separator: ", "))")
        print("[PROJECT] Assigned to: \(projectName ?? "None")")

        completion?(true, filePath)
    }

    // MARK: - Helper Methods

    private func saveImage(_ image: NSImage, to path: String) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return
        }

        try? pngData.write(to: URL(fileURLWithPath: path))
    }

    private func extractTextForAnalysis(from image: NSImage) -> String? {
        // Use existing OCR if available, or simple extraction
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let tagsManager = SmartTagsManager.shared
        // This uses the Vision framework internally
        return nil // Simplified for now
    }

    private func executeCapture(arguments: [String], completion: @escaping (Bool) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()

            let success = process.terminationStatus == 0
            DispatchQueue.main.async {
                completion(success)
            }
        } catch {
            print("[ERROR] Failed to execute screencapture: \(error)")
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }

    private func generateFilename(timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "Screenshot_\(formatter.string(from: timestamp)).png"
    }

    private func getSavePath(filename: String) -> String {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let picturesDirectory = homeDirectory.appendingPathComponent("Pictures/ScreenGrabber")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: picturesDirectory, withIntermediateDirectories: true)

        // Check if we have a project-specific folder
        if let project = ProjectWorkspaceManager.shared.activeProject,
           let projectFolder = project.folderPath {
            let projectURL = URL(fileURLWithPath: projectFolder)
            try? FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
            return projectURL.appendingPathComponent(filename).path
        }

        return picturesDirectory.appendingPathComponent(filename).path
    }

    private func showEnhancedNotification(
        filename: String,
        projectName: String?,
        tags: [String],
        wasTrimmed: Bool
    ) {
        var message = "Screenshot saved"

        if let project = projectName {
            message += " to \(project)"
        }

        if !tags.isEmpty {
            message += "\nTags: \(tags.prefix(3).joined(separator: ", "))"
            if tags.count > 3 {
                message += "..."
            }
        }

        if wasTrimmed {
            message += "\n✂️ Auto-trimmed"
        }

        print("[NOTIFICATION] \(message)")

        // Show system notification
        let notification = NSUserNotification()
        notification.title = "Screenshot Captured"
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName

        NSUserNotificationCenter.default.deliver(notification)
    }

    // MARK: - Capture Methods Enum

    enum CaptureMethod: String {
        case selectedArea = "selected_area"
        case window = "window"
        case fullScreen = "full_screen"
        case scrollingCapture = "scrolling_capture"
    }

    enum OutputOption: String {
        case clipboard = "clipboard"
        case saveToFile = "save_to_file"
        case preview = "preview"
    }
}
