//
//  TagsEditorView.swift
//  ScreenGrabber
//
//  UI for Smart Tags Management
//

import SwiftUI

struct TagsEditorView: View {
    @Binding var screenshot: Screenshot?
    @ObservedObject var tagsManager = SmartTagsManager.shared

    @State private var newTagText = ""
    @State private var showingSuggestions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)

            // Current tags
            if let screenshot = screenshot, !screenshot.allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(screenshot.allTags, id: \.self) { tag in
                            TagChip(
                                tag: tag,
                                isAutoTag: screenshot.autoTags.contains(tag),
                                onRemove: screenshot.tags.contains(tag) ? {
                                    screenshot.removeTag(tag)
                                } : nil
                            )
                        }
                    }
                }
            }

            // Add tag input
            HStack {
                Image(systemName: "tag")
                    .foregroundColor(.secondary)

                TextField("Add tag...", text: $newTagText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        addTag()
                    }
                    .onChange(of: newTagText) { oldValue, newValue in
                        showingSuggestions = !newValue.isEmpty
                    }

                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(newTagText.isEmpty)
            }

            // Suggestions
            if showingSuggestions && !newTagText.isEmpty {
                let suggestions = tagsManager.suggestTags(for: newTagText)
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Suggestions")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(suggestions.prefix(10), id: \.self) { tag in
                                    Button(tag) {
                                        screenshot?.addTag(tag)
                                        newTagText = ""
                                        showingSuggestions = false
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                    }
                }
            }

            // Common tags
            VStack(alignment: .leading, spacing: 6) {
                Text("Common Tags")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(SmartTagsManager.commonTags, id: \.self) { tag in
                            Button(tag) {
                                screenshot?.addTag(tag)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private func addTag() {
        guard !newTagText.isEmpty, let screenshot = screenshot else { return }
        screenshot.addTag(newTagText.lowercased())
        tagsManager.addTag(newTagText.lowercased())
        newTagText = ""
        showingSuggestions = false
    }
}

struct TagChip: View {
    let tag: String
    let isAutoTag: Bool
    let onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            if isAutoTag {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
            }

            Text(tag)
                .font(.caption)

            if let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isAutoTag ? Color.purple.opacity(0.2) : Color.accentColor.opacity(0.2))
        .cornerRadius(12)
    }
}

struct TagFilterView: View {
    @Binding var selectedTags: Set<String>
    @ObservedObject var tagsManager = SmartTagsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Filter by Tags")
                .font(.headline)

            if tagsManager.allTags.isEmpty {
                Text("No tags yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(tagsManager.allTags, id: \.self) { tag in
                            Button(action: {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            }) {
                                HStack {
                                    Image(systemName: selectedTags.contains(tag) ? "checkmark.square.fill" : "square")
                                    Text(tag)
                                        .font(.body)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            if !selectedTags.isEmpty {
                Button("Clear Filters") {
                    selectedTags.removeAll()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}
