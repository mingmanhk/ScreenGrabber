//
//  ImageContextMenu.swift
//  ScreenGrabber
//
//  Created by AI Assistant on 01/03/26.
//  Comprehensive context menu for image editing
//

import SwiftUI
import AppKit

struct ImageContextMenuModifier: ViewModifier {
    let imageURL: URL?
    let onAction: (ImageContextAction) -> Void
    
    func body(content: Content) -> some View {
        content
            .contextMenu {
                ImageContextMenuContent(imageURL: imageURL, onAction: onAction)
            }
    }
}

enum ImageContextAction {
    case copy
    case grabText
    case paste
    case pasteInPlace
    case flipHorizontal
    case flipVertical
    case flattenAll
    case trim
    case cropToCanvas
    case resizeCanvas
    case canvasSnapping
    case changeCanvasColor
    case removeBackground
    case applyTemplate
    
    // ViVi Integration
    case takePhoto
    case scanDocument
    case addSketch
}

struct ImageContextMenuContent: View {
    let imageURL: URL?
    let onAction: (ImageContextAction) -> Void
    
    var body: some View {
        Group {
            // Basic editing
            Button("Copy") {
                if let url = imageURL {
                    ClipboardHelper.copyImageToClipboard(from: url)
                }
                onAction(.copy)
            }
            .keyboardShortcut("c", modifiers: .command)
            
            Button("Grab Text...") {
                onAction(.grabText)
            }
            
            Divider()
            
            Button("Paste") {
                onAction(.paste)
            }
            .keyboardShortcut("v", modifiers: .command)
            
            Button("Paste In Place") {
                onAction(.pasteInPlace)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            
            Divider()
            
            // Transform menu
            Menu("Transform") {
                Button("Flip Horizontal") {
                    onAction(.flipHorizontal)
                }
                
                Button("Flip Vertical") {
                    onAction(.flipVertical)
                }
            }
            
            Button("Flatten All") {
                onAction(.flattenAll)
            }
            
            Divider()
            
            // Canvas operations
            Menu("Canvas") {
                Button("Trim") {
                    onAction(.trim)
                }
                
                Button("Crop to Canvas") {
                    onAction(.cropToCanvas)
                }
                
                Button("Resize Canvas...") {
                    onAction(.resizeCanvas)
                }
                
                Divider()
                
                Button("Canvas Snapping") {
                    onAction(.canvasSnapping)
                }
                
                Button("Change Canvas Color...") {
                    onAction(.changeCanvasColor)
                }
            }
            
            Divider()
            
            // AI-powered features
            Button("Remove Background") {
                onAction(.removeBackground)
            }
            
            Button("Apply Template...") {
                onAction(.applyTemplate)
            }
            
            Divider()
            
            // ViVi Integration
            Menu("ViVi Integration") {
                Button("Take Photo") {
                    onAction(.takePhoto)
                }
                
                Button("Scan Documents") {
                    onAction(.scanDocument)
                }
                
                Button("Add Sketch") {
                    onAction(.addSketch)
                }
            }
        }
    }
}

extension View {
    func imageContextMenu(imageURL: URL?, onAction: @escaping (ImageContextAction) -> Void) -> some View {
        modifier(ImageContextMenuModifier(imageURL: imageURL, onAction: onAction))
    }
}

#Preview {
    Rectangle()
        .fill(Color.gray)
        .frame(width: 300, height: 200)
        .imageContextMenu(imageURL: nil) { action in
            print("Action: \(action)")
        }
}
