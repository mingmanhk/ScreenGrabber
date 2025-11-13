//
//  ProjectSelectorView.swift
//  ScreenGrabber
//
//  UI for Project Workspace Management
//

import SwiftUI

struct ProjectSelectorView: View {
    @ObservedObject var manager = ProjectWorkspaceManager.shared
    @State private var showingNewProjectSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Project")
                    .font(.headline)

                Spacer()

                Button(action: { showingNewProjectSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
            }

            // Active project
            if let active = manager.activeProject {
                ProjectCard(project: active, isActive: true) {
                    manager.setActiveProject(nil)
                }
            } else {
                Text("No active project")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Recent projects
            if !manager.projects.isEmpty {
                Divider()

                Text("All Projects")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(manager.projects) { project in
                            ProjectCard(
                                project: project,
                                isActive: manager.activeProject?.id == project.id
                            ) {
                                if manager.activeProject?.id == project.id {
                                    manager.setActiveProject(nil)
                                } else {
                                    manager.setActiveProject(project)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(width: 300)
        .sheet(isPresented: $showingNewProjectSheet) {
            NewProjectSheet()
        }
    }
}

struct ProjectCard: View {
    let project: ProjectWorkspaceManager.Project
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: project.icon)
                    .font(.title2)
                    .foregroundColor(Color(project.nsColor))
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.body)
                        .fontWeight(isActive ? .semibold : .regular)

                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Label("\(project.screenshotCount)", systemImage: "photo")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(project.lastUsedDate, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(12)
            .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct NewProjectSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var manager = ProjectWorkspaceManager.shared

    @State private var projectName = ""
    @State private var projectDescription = ""
    @State private var selectedColor = Color.blue
    @State private var selectedIcon = "folder"

    let availableIcons = [
        "folder", "folder.fill", "briefcase", "briefcase.fill",
        "person.circle", "person.circle.fill", "paintbrush", "paintbrush.fill",
        "chevron.left.forwardslash.chevron.right", "doc.text", "doc.text.fill",
        "book", "book.fill", "lightbulb", "lightbulb.fill",
        "star", "star.fill", "heart", "heart.fill"
    ]

    var body: some View {
        VStack(spacing: 20) {
            Text("New Project")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("Project Name", text: $projectName)
                    .textFieldStyle(.roundedBorder)

                TextField("Description (optional)", text: $projectDescription)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon")
                        .font(.caption)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button(action: { selectedIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                ColorPicker("Color", selection: $selectedColor)
            }
            .padding()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Create") {
                    createProject()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(projectName.isEmpty)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 500)
    }

    private func createProject() {
        let color = NSColor(selectedColor).toHex()
        let project = manager.createProject(
            name: projectName,
            description: projectDescription,
            color: color,
            icon: selectedIcon
        )
        manager.setActiveProject(project)
        dismiss()
    }
}

struct ProjectWorkspaceSettings: View {
    @ObservedObject var manager = ProjectWorkspaceManager.shared

    var body: some View {
        Form {
            Section("Project Settings") {
                Toggle("Auto-detect project from content", isOn: $manager.autoDetectProject)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Statistics")
                        .font(.headline)

                    HStack {
                        Text("Total Screenshots:")
                        Spacer()
                        Text("\(manager.getTotalScreenshots())")
                            .fontWeight(.semibold)
                    }

                    if let mostUsed = manager.getMostUsedProject() {
                        HStack {
                            Text("Most Used Project:")
                            Spacer()
                            Text(mostUsed.name)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .padding()
    }
}
