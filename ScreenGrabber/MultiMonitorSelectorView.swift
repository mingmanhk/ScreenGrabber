//
//  MultiMonitorSelectorView.swift
//  ScreenGrabber
//
//  UI for Multi-Monitor Control
//

import SwiftUI

struct MultiMonitorSelectorView: View {
    @ObservedObject var manager = MultiMonitorManager.shared
    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Display Selection")
                    .font(.headline)

                Spacer()

                Button(action: refreshDisplays) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }

            if manager.availableDisplays.isEmpty {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Detecting displays...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // Display arrangement info
                if manager.availableDisplays.count > 1 {
                    Text(manager.getDisplayArrangement())
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                }

                // Display list
                ForEach(manager.availableDisplays) { display in
                    DisplayCard(
                        display: display,
                        isSelected: manager.selectedDisplay?.id == display.id
                    ) {
                        manager.selectDisplay(display)
                    }
                }

                Divider()

                // Quick select options
                if manager.availableDisplays.count > 1 {
                    HStack {
                        Button("Primary") {
                            manager.selectPrimaryDisplay()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Next") {
                            manager.selectNextDisplay()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut("]", modifiers: .command)

                        Button("Previous") {
                            manager.selectPreviousDisplay()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut("[", modifiers: .command)
                    }
                }

                // Preferences
                Toggle("Remember display preference", isOn: $manager.rememberDisplayPreference)
                    .font(.caption)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            manager.refreshDisplays()
        }
    }

    private func refreshDisplays() {
        isRefreshing = true
        manager.refreshDisplays()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isRefreshing = false
        }
    }
}

struct DisplayCard: View {
    let display: MultiMonitorManager.Display
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Display icon
                ZStack {
                    Image(systemName: "display")
                        .font(.title2)
                        .foregroundColor(isSelected ? .accentColor : .primary)

                    if display.isPrimary {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                            .offset(x: 12, y: -12)
                    }
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(display.name)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(display.resolution)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(display.aspectRatio)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if display.isPrimary {
                        Text("Primary Display")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

struct MultiMonitorMenuView: View {
    @ObservedObject var manager = MultiMonitorManager.shared

    var body: some View {
        Menu {
            if manager.availableDisplays.isEmpty {
                Text("No displays detected")
            } else {
                ForEach(manager.availableDisplays) { display in
                    Button(action: {
                        manager.selectDisplay(display)
                    }) {
                        HStack {
                            Image(systemName: "display")
                            Text(display.description)

                            if manager.selectedDisplay?.id == display.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if manager.availableDisplays.count > 1 {
                    Divider()

                    Button("Next Display") {
                        manager.selectNextDisplay()
                    }
                    .keyboardShortcut("]", modifiers: .command)

                    Button("Previous Display") {
                        manager.selectPreviousDisplay()
                    }
                    .keyboardShortcut("[", modifiers: .command)
                }
            }
        } label: {
            HStack {
                Image(systemName: "display")
                if let selected = manager.selectedDisplay {
                    Text(selected.name)
                        .lineLimit(1)
                } else {
                    Text("Select Display")
                }
            }
        }
    }
}
