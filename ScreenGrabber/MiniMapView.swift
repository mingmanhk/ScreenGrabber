//
//  MiniMapView.swift
//  ScreenGrabber
//
//  Mini-map for navigating tall screenshots
//

import SwiftUI

struct MiniMapView: View {
    let image: NSImage
    let annotations: [Annotation]
    let scrollOffset: CGPoint
    
    @State private var miniMapImage: NSImage?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background
                Color(NSColor.controlBackgroundColor)
                
                // Mini image
                if let miniImage = miniMapImage {
                    Image(nsImage: miniImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: geometry.size.height - 16)
                        .padding(8)
                    
                    // Viewport indicator
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 2)
                        .fill(Color.blue.opacity(0.1))
                        .frame(
                            width: calculateViewportWidth(in: geometry.size),
                            height: calculateViewportHeight(in: geometry.size)
                        )
                        .offset(
                            x: calculateViewportX(in: geometry.size),
                            y: calculateViewportY(in: geometry.size)
                        )
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            generateMiniMap()
        }
    }
    
    private func generateMiniMap() {
        let targetHeight: CGFloat = 100
        let aspectRatio = image.size.width / image.size.height
        let targetWidth = targetHeight * aspectRatio
        let targetSize = NSSize(width: targetWidth, height: targetHeight)
        
        let miniImage = NSImage(size: targetSize)
        miniImage.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        miniImage.unlockFocus()
        
        self.miniMapImage = miniImage
    }
    
    private func calculateViewportWidth(in size: CGSize) -> CGFloat {
        // Simplified calculation - would need actual viewport size
        return size.width * 0.8
    }
    
    private func calculateViewportHeight(in size: CGSize) -> CGFloat {
        return 20
    }
    
    private func calculateViewportX(in size: CGSize) -> CGFloat {
        return 8
    }
    
    private func calculateViewportY(in size: CGSize) -> CGFloat {
        // Calculate based on scroll offset
        let ratio = scrollOffset.y / image.size.height
        return ratio * (size.height - 16) + 8
    }
}

#Preview {
    MiniMapView(
        image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!,
        annotations: [],
        scrollOffset: .zero
    )
    .frame(height: 120)
}
