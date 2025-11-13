//
//  ProjectWorkspaceManager.swift
//  ScreenGrabber
//
//  Project Workspaces - Organize screenshots by project
//

import Foundation
import AppKit
import SwiftUI

class ProjectWorkspaceManager: ObservableObject {
    static let shared = ProjectWorkspaceManager()

    @Published var projects: [Project] = []
    @Published var activeProject: Project?
    @Published var autoDetectProject = true

    private let projectsKey = "screenshotProjects"
    private let activeProjectKey = "activeProject"

    private init() {
        loadProjects()
        loadActiveProject()
    }

    // MARK: - Project Model

    struct Project: Identifiable, Codable, Equatable {
        let id: UUID
        var name: String
        var description: String
        var color: String // Hex color
        var icon: String // SF Symbol name
        var folderPath: String?
        var createdDate: Date
        var lastUsedDate: Date
        var screenshotCount: Int

        init(id: UUID = UUID(), name: String, description: String = "", color: String = "#007AFF", icon: String = "folder", folderPath: String? = nil, createdDate: Date = Date(), lastUsedDate: Date = Date(), screenshotCount: Int = 0) {
            self.id = id
            self.name = name
            self.description = description
            self.color = color
            self.icon = icon
            self.folderPath = folderPath
            self.createdDate = createdDate
            self.lastUsedDate = lastUsedDate
            self.screenshotCount = screenshotCount
        }

        var nsColor: NSColor {
            return NSColor(hex: color) ?? NSColor.systemBlue
        }
    }

    // MARK: - Persistence

    private func loadProjects() {
        if let data = UserDefaults.standard.data(forKey: projectsKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded
        }

        // Add default projects if none exist
        if projects.isEmpty {
            addDefaultProjects()
        }
    }

    private func saveProjects() {
        if let encoded = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(encoded, forKey: projectsKey)
        }
    }

    private func loadActiveProject() {
        if let data = UserDefaults.standard.data(forKey: activeProjectKey),
           let decoded = try? JSONDecoder().decode(Project.self, from: data) {
            // Find matching project in current list
            activeProject = projects.first { $0.id == decoded.id }
        }
    }

    private func saveActiveProject() {
        if let project = activeProject,
           let encoded = try? JSONEncoder().encode(project) {
            UserDefaults.standard.set(encoded, forKey: activeProjectKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeProjectKey)
        }
    }

    private func addDefaultProjects() {
        projects = [
            Project(name: "Personal", description: "Personal screenshots", color: "#007AFF", icon: "person.circle"),
            Project(name: "Work", description: "Work-related screenshots", color: "#34C759", icon: "briefcase"),
            Project(name: "Design", description: "Design and mockups", color: "#FF9500", icon: "paintbrush"),
            Project(name: "Development", description: "Code and development", color: "#5856D6", icon: "chevron.left.forwardslash.chevron.right"),
            Project(name: "Documentation", description: "Docs and guides", color: "#FF3B30", icon: "doc.text")
        ]
        saveProjects()
    }

    // MARK: - Project Management

    func createProject(name: String, description: String = "", color: String = "#007AFF", icon: String = "folder", folderPath: String? = nil) -> Project {
        let project = Project(name: name, description: description, color: color, icon: icon, folderPath: folderPath)
        projects.append(project)
        saveProjects()
        return project
    }

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            var updatedProject = project
            updatedProject.lastUsedDate = Date()
            projects[index] = updatedProject
            saveProjects()

            // Update active project if it's the one being modified
            if activeProject?.id == project.id {
                activeProject = updatedProject
                saveActiveProject()
            }
        }
    }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        saveProjects()

        if activeProject?.id == project.id {
            activeProject = nil
            saveActiveProject()
        }
    }

    func setActiveProject(_ project: Project?) {
        activeProject = project
        if var project = project {
            project.lastUsedDate = Date()
            updateProject(project)
        }
        saveActiveProject()
    }

    func incrementScreenshotCount(for project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].screenshotCount += 1
            projects[index].lastUsedDate = Date()
            saveProjects()
        }
    }

    // MARK: - Auto Detection

    func detectProject(from text: String?, windowTitle: String?) -> Project? {
        guard autoDetectProject else { return activeProject }

        // Check active project first
        if let active = activeProject {
            return active
        }

        // Try to detect from window title or content
        let searchText = "\(windowTitle ?? "") \(text ?? "")".lowercased()

        // Match against project names and keywords
        let keywords: [String: String] = [
            "xcode": "Development",
            "vscode": "Development",
            "terminal": "Development",
            "github": "Development",
            "figma": "Design",
            "sketch": "Design",
            "photoshop": "Design",
            "illustrator": "Design",
            "safari": "Personal",
            "chrome": "Personal",
            "slack": "Work",
            "teams": "Work",
            "notion": "Documentation",
            "confluence": "Documentation"
        ]

        for (keyword, projectName) in keywords {
            if searchText.contains(keyword) {
                return projects.first { $0.name == projectName }
            }
        }

        return nil
    }

    // MARK: - Project Folder Management

    func createProjectFolder(for project: Project, in baseDirectory: URL) -> URL? {
        let folderURL = baseDirectory.appendingPathComponent(project.name, isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

            var updatedProject = project
            updatedProject.folderPath = folderURL.path
            updateProject(updatedProject)

            return folderURL
        } catch {
            print("Error creating project folder: \(error)")
            return nil
        }
    }

    // MARK: - Statistics

    func getTotalScreenshots() -> Int {
        return projects.reduce(0) { $0 + $1.screenshotCount }
    }

    func getMostUsedProject() -> Project? {
        return projects.max(by: { $0.screenshotCount < $1.screenshotCount })
    }

    func getRecentProjects(limit: Int = 5) -> [Project] {
        return projects.sorted { $0.lastUsedDate > $1.lastUsedDate }.prefix(limit).map { $0 }
    }
}

// MARK: - NSColor Extension

extension NSColor {
    convenience init?(hex: String) {
        let r, g, b: CGFloat

        let hexColor = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))

        guard hexColor.count == 6 else { return nil }

        let scanner = Scanner(string: hexColor)
        var hexNumber: UInt64 = 0

        guard scanner.scanHexInt64(&hexNumber) else { return nil }

        r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
        g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
        b = CGFloat(hexNumber & 0x0000ff) / 255

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    func toHex() -> String {
        guard let rgb = cgColor.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)?.components else {
            return "#000000"
        }

        let r = Int(rgb[0] * 255)
        let g = Int(rgb[1] * 255)
        let b = Int(rgb[2] * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
