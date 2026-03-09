//
//  HelpTextViews.swift
//  ScreenGrabber
//
//  Created on 01/17/26.
//  Reusable help text and tooltip components
//

import SwiftUI

// MARK: - Help Text View

/// A styled help text view with icon and description
struct HelpTextView: View {
    let icon: String
    let title: String
    let description: String
    var iconColor: Color = .blue
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Inline Help

/// Small inline help text with optional popover
struct InlineHelp: View {
    let text: String
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .opacity(isHovering ? 1.0 : 0.7)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Help Popover

/// A help button that shows a popover with detailed information
struct HelpPopover: View {
    let title: String
    let content: String
    let steps: [HelpStep]?
    
    @State private var showingPopover = false
    
    init(title: String, content: String, steps: [HelpStep]? = nil) {
        self.title = title
        self.content = content
        self.steps = steps
    }
    
    var body: some View {
        Button {
            showingPopover.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.body)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .popover(isPresented: $showingPopover, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(title)
                    .font(.headline)
                
                // Content
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Steps (if provided)
                if let steps = steps {
                    Divider()
                        .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1).")
                                    .font(.caption.bold())
                                    .foregroundStyle(.blue)
                                    .frame(width: 20, alignment: .trailing)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.title)
                                        .font(.caption.bold())
                                    if let description = step.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: 280)
            .padding(16)
        }
    }
    
    struct HelpStep {
        let title: String
        let description: String?
        
        init(_ title: String, description: String? = nil) {
            self.title = title
            self.description = description
        }
    }
}

// MARK: - Feature Help Cards

/// Pre-configured help cards for complex features
enum FeatureHelp {
    
    // MARK: - Scrolling Capture
    
    static var scrollingCapture: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpTextView(
                icon: "arrow.down.doc",
                title: "Scrolling Capture",
                description: "Automatically captures long pages by scrolling through content",
                iconColor: .purple
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("How it works:")
                    .font(.subheadline.bold())
                
                StepRow(number: 1, text: "Select the scrollable area or window")
                StepRow(number: 2, text: "Click \"Start Scrolling Capture\"")
                StepRow(number: 3, text: "The page scrolls automatically")
                StepRow(number: 4, text: "Images are stitched together seamlessly")
            }
            .padding(.leading, 8)
            
            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.yellow)
                Text("Tip: Works best with web pages and long documents")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
    
    // MARK: - Window Selection
    
    static var windowSelection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpTextView(
                icon: "macwindow",
                title: "Window Selection",
                description: "Capture specific windows with precise control",
                iconColor: .blue
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Selection modes:")
                    .font(.subheadline.bold())
                
                FeatureRow(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Area Selection",
                    description: "Click and drag to select any area"
                )
                
                FeatureRow(
                    icon: "macwindow",
                    title: "Window Selection",
                    description: "Hover over windows and click to select"
                )
                
                HStack(spacing: 6) {
                    Image(systemName: "keyboard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Press")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Space")
                        .font(.caption.monospaced())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                    Text("to switch modes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(.leading, 8)
        }
    }
    
    // MARK: - Annotation Tools
    
    static var annotationTools: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpTextView(
                icon: "pencil.tip.crop.circle",
                title: "Annotation Tools",
                description: "Edit and annotate your screenshots with powerful tools",
                iconColor: .orange
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Available tools:")
                    .font(.subheadline.bold())
                
                AnnotationToolRow(
                    icon: "arrow.right",
                    name: "Arrow",
                    shortcut: "A",
                    description: "Point to important areas"
                )
                
                AnnotationToolRow(
                    icon: "pencil",
                    name: "Pen",
                    shortcut: "P",
                    description: "Draw freehand"
                )
                
                AnnotationToolRow(
                    icon: "textformat",
                    name: "Text",
                    shortcut: "T",
                    description: "Add text labels"
                )
                
                AnnotationToolRow(
                    icon: "rectangle",
                    name: "Shape",
                    shortcut: "S",
                    description: "Add rectangles and circles"
                )
                
                AnnotationToolRow(
                    icon: "paintbrush",
                    name: "Highlight",
                    shortcut: "H",
                    description: "Emphasize text or areas"
                )
            }
            .padding(.leading, 8)
            
            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.yellow)
                Text("Tip: Use keyboard shortcuts for quick tool switching")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
    
    // MARK: - Save Location
    
    static var saveLocation: some View {
        VStack(alignment: .leading, spacing: 16) {
            HelpTextView(
                icon: "folder",
                title: "Save Location",
                description: "Choose where your screenshots are saved",
                iconColor: .purple
            )
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Default location:")
                    .font(.subheadline.bold())
                
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text("~/Pictures/Screen Grabber/")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.leading, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Organization:")
                    .font(.subheadline.bold())
                
                StepRow(number: 1, text: "Screenshots are grouped by date")
                StepRow(number: 2, text: "Names include timestamp for easy sorting")
                StepRow(number: 3, text: "Duplicates are automatically renamed")
            }
            .padding(.leading, 8)
            
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.blue)
                Text("The folder must be accessible and writable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - Helper Components

private struct StepRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number).")
                .font(.caption.bold())
                .foregroundStyle(.blue)
                .frame(width: 20, alignment: .trailing)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AnnotationToolRow: View {
    let icon: String
    let name: String
    let shortcut: String
    let description: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.caption.bold())
                    Text(shortcut)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Previews

#Preview("Help Text Views") {
    ScrollView {
        VStack(spacing: 24) {
            Group {
                Text("Basic Help Text")
                    .font(.title2.bold())
                
                HelpTextView(
                    icon: "info.circle",
                    title: "Information",
                    description: "This is a basic help text view with an icon and description"
                )
                
                Divider()
            }
            
            Group {
                Text("Inline Help")
                    .font(.title2.bold())
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Setting Name")
                        Spacer()
                        Toggle("", isOn: .constant(true))
                    }
                    InlineHelp(text: "This setting controls the behavior of the feature")
                }
                
                Divider()
            }
            
            Group {
                Text("Help Popover")
                    .font(.title2.bold())
                
                HStack {
                    Text("Complex Feature")
                    HelpPopover(
                        title: "How It Works",
                        content: "This feature requires multiple steps to configure properly.",
                        steps: [
                            .init("First Step", description: "Do this first"),
                            .init("Second Step", description: "Then do this"),
                            .init("Third Step", description: "Finally complete this")
                        ]
                    )
                }
                
                Divider()
            }
            
            Group {
                Text("Feature Help Cards")
                    .font(.title2.bold())
                
                FeatureHelp.scrollingCapture
                FeatureHelp.windowSelection
                FeatureHelp.annotationTools
                FeatureHelp.saveLocation
            }
        }
        .padding(20)
    }
    .frame(width: 500, height: 800)
}
