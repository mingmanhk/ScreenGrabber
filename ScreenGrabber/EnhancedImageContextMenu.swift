//
//  EnhancedImageContextMenu.swift
//  ScreenGrabber
//
//  Enhanced context menu for images with all editing features
//

import SwiftUI
import AppKit

struct EnhancedImageContextMenu: View {
    let image: NSImage?
    var onAction: (ContextMenuAction) -> Void
    
    var body: some View {
        Group {
            // Basic Actions
            Button("Copy") {
                onAction(.copy)
            }
            .keyboardShortcut("c", modifiers: .command)
            
            Menu("Grab Text...") {
                Button("From Selection") {
                    onAction(.grabTextSelection)
                }
                Button("From Entire Image") {
                    onAction(.grabTextFull)
                }
            }
            
            Divider()
            
            // Clipboard Actions
            Button("Paste") {
                onAction(.paste)
            }
            .keyboardShortcut("v", modifiers: .command)
            
            Button("Paste In Place") {
                onAction(.pasteInPlace)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            
            Divider()
            
            // Transform Actions
            Button("Flip Horizontal") {
                onAction(.flipHorizontal)
            }
            
            Button("Flip Vertically") {
                onAction(.flipVertical)
            }
            
            Divider()
            
            // Layer Actions
            Button("Flatten All") {
                onAction(.flattenAll)
            }
            
            Divider()
            
            // Canvas Actions
            Button("Trim") {
                onAction(.trim)
            }
            
            Button("Crop to Canvas") {
                onAction(.cropToCanvas)
            }
            
            Button("Resize Canvas...") {
                onAction(.resizeCanvas)
            }
            
            Menu("Canvas Snapping") {
                Button("Snap to Grid") {
                    onAction(.snapToGrid)
                }
                Button("Snap to Guides") {
                    onAction(.snapToGuides)
                }
                Button("No Snapping") {
                    onAction(.noSnapping)
                }
            }
            
            Button("Change Canvas Color...") {
                onAction(.changeCanvasColor)
            }
            
            Divider()
            
            // AI Actions
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
                    onAction(.viviTakePhoto)
                }
                
                Button("Scan Documents") {
                    onAction(.viviScanDocuments)
                }
                
                Button("Add Sketch") {
                    onAction(.viviAddSketch)
                }
            }
        }
    }
}

// MARK: - Context Menu Actions
enum ContextMenuAction {
    // Basic
    case copy
    case grabTextSelection
    case grabTextFull
    
    // Clipboard
    case paste
    case pasteInPlace
    
    // Transform
    case flipHorizontal
    case flipVertical
    
    // Layers
    case flattenAll
    
    // Canvas
    case trim
    case cropToCanvas
    case resizeCanvas
    case snapToGrid
    case snapToGuides
    case noSnapping
    case changeCanvasColor
    
    // AI
    case removeBackground
    case applyTemplate
    
    // ViVi
    case viviTakePhoto
    case viviScanDocuments
    case viviAddSketch
}

// MARK: - Context Menu Builder (for NSView integration)
// Note: This extension provides an NSMenu for AppKit contexts, but the handler
// parameter is not currently connected. To properly use this menu with actions,
// you would need to implement a coordinator or delegate class that can receive
// the action callbacks. For SwiftUI contexts, use EnhancedImageContextMenu directly.
extension NSImage {
    func buildEnhancedContextMenu(handler: @escaping (ContextMenuAction) -> Void) -> NSMenu {
        let menu = NSMenu()
        
        // Basic Actions
        // Note: Using nil action since we can't directly connect to the handler
        // In a real implementation, you'd need a target object that bridges to the handler
        let copyItem = NSMenuItem(title: "Copy", action: nil, keyEquivalent: "c")
        copyItem.keyEquivalentModifierMask = .command
        menu.addItem(copyItem)
        
        let grabTextMenu = NSMenuItem(title: "Grab Text...", action: nil, keyEquivalent: "")
        let grabTextSubmenu = NSMenu()
        grabTextSubmenu.addItem(withTitle: "From Selection", action: nil, keyEquivalent: "")
        grabTextSubmenu.addItem(withTitle: "From Entire Image", action: nil, keyEquivalent: "")
        grabTextMenu.submenu = grabTextSubmenu
        menu.addItem(grabTextMenu)
        
        menu.addItem(.separator())
        
        // Clipboard
        let pasteItem = NSMenuItem(title: "Paste", action: nil, keyEquivalent: "v")
        pasteItem.keyEquivalentModifierMask = .command
        menu.addItem(pasteItem)
        
        let pasteInPlaceItem = NSMenuItem(title: "Paste In Place", action: nil, keyEquivalent: "V")
        pasteInPlaceItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(pasteInPlaceItem)
        
        menu.addItem(.separator())
        
        // Transform
        menu.addItem(withTitle: "Flip Horizontal", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Flip Vertically", action: nil, keyEquivalent: "")
        
        menu.addItem(.separator())
        
        // Layers
        menu.addItem(withTitle: "Flatten All", action: nil, keyEquivalent: "")
        
        menu.addItem(.separator())
        
        // Canvas
        menu.addItem(withTitle: "Trim", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Crop to Canvas", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Resize Canvas...", action: nil, keyEquivalent: "")
        
        let snappingMenu = NSMenuItem(title: "Canvas Snapping", action: nil, keyEquivalent: "")
        let snappingSubmenu = NSMenu()
        snappingSubmenu.addItem(withTitle: "Snap to Grid", action: nil, keyEquivalent: "")
        snappingSubmenu.addItem(withTitle: "Snap to Guides", action: nil, keyEquivalent: "")
        snappingSubmenu.addItem(withTitle: "No Snapping", action: nil, keyEquivalent: "")
        snappingMenu.submenu = snappingSubmenu
        menu.addItem(snappingMenu)
        
        menu.addItem(withTitle: "Change Canvas Color...", action: nil, keyEquivalent: "")
        
        menu.addItem(.separator())
        
        // AI
        menu.addItem(withTitle: "Remove Background", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Apply Template...", action: nil, keyEquivalent: "")
        
        menu.addItem(.separator())
        
        // ViVi
        let viviMenu = NSMenuItem(title: "ViVi Integration", action: nil, keyEquivalent: "")
        let viviSubmenu = NSMenu()
        viviSubmenu.addItem(withTitle: "Take Photo", action: nil, keyEquivalent: "")
        viviSubmenu.addItem(withTitle: "Scan Documents", action: nil, keyEquivalent: "")
        viviSubmenu.addItem(withTitle: "Add Sketch", action: nil, keyEquivalent: "")
        viviMenu.submenu = viviSubmenu
        menu.addItem(viviMenu)
        
        return menu
    }
}

#Preview {
    VStack {
        Text("Right-click to see context menu")
    }
    .frame(width: 300, height: 200)
    .contextMenu {
        EnhancedImageContextMenu(image: nil) { action in
            print("Action: \(action)")
        }
    }
}
