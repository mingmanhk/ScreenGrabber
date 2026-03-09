import AppKit
import Accelerate

enum ImageStitcher {
    /// Basic vertical stitching
    static func stitchVertically(frames: [NSImage], overlap: CGFloat) -> NSImage? {
        guard !frames.isEmpty else { return nil }
        let width = frames.map { $0.size.width }.max() ?? 0
        var totalHeight: CGFloat = frames[0].size.height
        for i in 1..<frames.count {
            totalHeight += frames[i].size.height - overlap
        }
        
        let finalImage = NSImage(size: NSSize(width: width, height: totalHeight))
        finalImage.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: finalImage.size).fill()

        var y: CGFloat = 0
        for (i, img) in frames.enumerated() {
            img.draw(in: NSRect(x: 0, y: y, width: img.size.width, height: img.size.height))
            y += img.size.height - (i == frames.count - 1 ? 0 : overlap)
        }
        finalImage.unlockFocus()
        return finalImage
    }
    
    /// Smart stitching that handles sticky headers by cropping overlapped regions
    static func stitchVerticallyWithEdgeMatching(frames: [NSImage], overlap: CGFloat) -> NSImage? {
        guard !frames.isEmpty else { return nil }
        guard frames.count > 1 else { return frames.first }
        
        print("🔍 Smart Stitching...")
        let width = frames.map { $0.size.width }.max() ?? 0
        
        var offsets: [CGFloat] = [0]
        
        // Calculate offsets
        for i in 1..<frames.count {
            let prev = frames[i-1]
            let curr = frames[i]
            
            // Search deeper (up to 40% of frame) to skip sticky headers
            let searchH = min(curr.size.height * 0.4, 600.0)
            
            let overlapAmount = findOverlapAmount(prev: prev, curr: curr, searchHeight: searchH, expected: overlap)
            
            // Current frame starts where Previous frame ends, minus overlap
            let prevY = offsets.last ?? 0
            let nextY = prevY + prev.size.height - overlapAmount
            offsets.append(nextY)
        }
        
        let totalHeight = (offsets.last ?? 0) + (frames.last?.size.height ?? 0)
        let size = NSSize(width: width, height: totalHeight)
        let finalImage = NSImage(size: size)
        
        finalImage.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: size).fill()
        
        for (i, img) in frames.enumerated() {
            let y = offsets[i]
            
            if i == 0 {
                img.draw(in: NSRect(x: 0, y: y, width: img.size.width, height: img.size.height))
            } else {
                // Calculate how much we overlapped with previous
                let prevY = offsets[i-1]
                let prevH = frames[i-1].size.height
                let actualOverlap = (prevY + prevH) - y
                
                // Crop the top 'actualOverlap' amount from current image
                // This effectively removes sticky headers that were matched
                let drawH = img.size.height - actualOverlap
                
                if drawH > 0 {
                    // Source: Bottom part of image (excluding top 'actualOverlap')
                    // NSImage coords: (0,0) is bottom-left. 
                    // To crop top, we keep y:0 to y:drawH
                    let sourceRect = NSRect(x: 0, y: 0, width: img.size.width, height: drawH)
                    
                    // Dest: y + actualOverlap
                    let destRect = NSRect(x: 0, y: y + actualOverlap, width: img.size.width, height: drawH)
                    
                    img.draw(in: destRect, from: sourceRect, operation: .sourceOver, fraction: 1.0)
                }
            }
        }
        finalImage.unlockFocus()
        return finalImage
    }
    
    private static func findOverlapAmount(prev: NSImage, curr: NSImage, searchHeight: CGFloat, expected: CGFloat) -> CGFloat {
        let stripH: CGFloat = 40
        // Get bottom strip of prev
        guard let prevRep = getRep(prev, rect: NSRect(x: 0, y: 0, width: prev.size.width, height: stripH)),
              let _ = NSBitmapImageRep(data: curr.tiffRepresentation ?? Data()) else { return expected }
        
        // Search in top of curr (y from H-searchH to H)
        // NSBitmap coords are top-left (0,0 is top-left) for pixels usually, 
        // BUT NSImage drawing into it is flipped? NSBitmapImageRep usually follows image.
        // Let's assume (0,0) is top-left in bitmapData buffer usually.
        
        // Wait, NSImage coordinate (0,0) is Bottom-Left.
        // We extracted bottom strip of Prev (y:0 to y:40).
        // We want to find this content in Curr. 
        // In Curr, this content should be somewhere near Top (High Y).
        
        // Let's use image drawing to compare to avoid coordinate hell.
        var bestOverlap = expected
        var minDiff = Double.greatestFiniteMagnitude
        
        // Helper to diff
        func diffAt(_ yOffsetFromTop: CGFloat) -> Double {
            // Compare Prev(Bottom) with Curr(Top - yOffset)
            // Prev Bottom is fixed.
            // Curr Top - offset: means we take a strip from Curr at Y = (H - stripH - yOffset)
            let checkY = curr.size.height - stripH - yOffsetFromTop
            if checkY < 0 { return Double.greatestFiniteMagnitude }
            
            guard let cRep = getRep(curr, rect: NSRect(x: 0, y: checkY, width: curr.size.width, height: stripH)) else { return Double.greatestFiniteMagnitude }
            
            return diffBitmaps(prevRep, cRep)
        }
        
        // Search
        let step: CGFloat = 2
        for offset in stride(from: 0, through: searchHeight, by: step) {
            let d = diffAt(offset)
            if d < minDiff {
                minDiff = d
                // If we match at 'offset' from top, 
                // it means the top 'offset' pixels of Curr are new/header, 
                // and the strip matches below that.
                // The overlap is actually: (Height of Curr - Y_coord_of_match).
                // Y_coord_of_match is (H - stripH - offset).
                // So content matches at that Y.
                // This means Prev ends at that Y.
                // So Curr is placed such that its Y aligns with Prev Bottom.
                // The overlap amount = (Top of Curr - Y match) = offset + stripH? 
                
                // Let's rethink stitch logic.
                // stitch: nextY = prevY + prevH - overlap.
                // => overlap = prevY + prevH - nextY.
                // We want nextY such that Curr(Y match) aligns with Prev(Top). No.
                // We want Curr(Y match) to align with Prev(Bottom).
                
                // Prev Bottom is visual content C.
                // Curr at (H - offset - stripH) is content C.
                // So we want to shift Curr UP so that (H - offset - stripH) aligns with Prev Bottom.
                // If overlap = (offset + stripH), then
                // nextY = prevY + prevH - (offset + stripH).
                // Top of Curr is at nextY + H.
                // Strip in Curr is at nextY + (H - offset - stripH) ? No, coords are messy.
                
                // Simpler: 
                // Overlap = Amount of content in Curr that is *already present* in Prev.
                // This is exactly (Height - MatchY).
                // MatchY is (H - offset - stripH).
                // So Overlap = offset + stripH.
                bestOverlap = offset + stripH
            }
            if minDiff < 1.0 { break }
        }
        
        return minDiff < 50 ? bestOverlap : expected
    }
    
    private static func getRep(_ img: NSImage, rect: NSRect) -> NSBitmapImageRep? {
        let sub = NSImage(size: rect.size)
        sub.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: rect.size), from: rect, operation: .copy, fraction: 1.0)
        sub.unlockFocus()
        return NSBitmapImageRep(data: sub.tiffRepresentation ?? Data())
    }
    
    private static func diffBitmaps(_ b1: NSBitmapImageRep, _ b2: NSBitmapImageRep) -> Double {
        guard let d1 = b1.bitmapData, let d2 = b2.bitmapData else { return 999 }
        let count = min(b1.bytesPerRow * b1.pixelsHigh, b2.bytesPerRow * b2.pixelsHigh)
        var diff: Int = 0
        let skip = 16 // sparse sample
        for i in stride(from: 0, to: count, by: skip) {
            diff += abs(Int(d1[i]) - Int(d2[i]))
        }
        return Double(diff) / Double(count/skip)
    }
}
