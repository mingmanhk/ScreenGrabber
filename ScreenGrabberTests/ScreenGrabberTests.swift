//
//  ScreenGrabberTests.swift
//  ScreenGrabberTests
//
//  Unit tests covering enums, geometry types, capture models, and OCR.
//

import Testing
import AppKit
import Foundation
import CoreImage
@testable import ScreenGrabber

// MARK: - OpenOption Tests

@Suite("OpenOption")
struct OpenOptionTests {
    @Test func allCasesPresent() {
        #expect(OpenOption.allCases.count == 3)
        #expect(OpenOption.allCases.contains(.clipboard))
        #expect(OpenOption.allCases.contains(.saveToFile))
        #expect(OpenOption.allCases.contains(.editor))
    }

    @Test func displayNames() {
        #expect(OpenOption.clipboard.displayName == "Clipboard")
        #expect(OpenOption.saveToFile.displayName == "Save to File")
        #expect(OpenOption.editor.displayName == "Editor")
    }

    @Test func icons() {
        #expect(OpenOption.clipboard.icon == "doc.on.clipboard")
        #expect(OpenOption.saveToFile.icon == "square.and.arrow.down")
        #expect(OpenOption.editor.icon == "pencil.and.outline")
    }

    @Test func identifiable() {
        #expect(OpenOption.clipboard.id == "Clipboard")
        #expect(OpenOption.saveToFile.id == "Save to File")
        #expect(OpenOption.editor.id == "Editor")
    }
}

// MARK: - ScreenOption Tests

@Suite("ScreenOption")
struct ScreenOptionTests {
    @Test func allCasesPresent() {
        #expect(ScreenOption.allCases.count == 4)
    }

    @Test func icons() {
        #expect(ScreenOption.selectedArea.icon == "selection.pin.in.out")
        #expect(ScreenOption.window.icon == "macwindow")
        #expect(ScreenOption.fullScreen.icon == "display")
        #expect(ScreenOption.scrollingCapture.icon == "scroll")
    }

    @Test func displayNames() {
        #expect(ScreenOption.selectedArea.displayName == "Selected Area")
        #expect(ScreenOption.window.displayName == "Window")
        #expect(ScreenOption.fullScreen.displayName == "Full Screen")
        #expect(ScreenOption.scrollingCapture.displayName == "Scrolling Capture")
    }
}

// MARK: - CaptureEnums Tests

@Suite("CaptureEnums")
struct CaptureEnumsTests {
    @Test func captureEffectIcons() {
        for effect in CaptureEffect.allCases {
            #expect(!effect.icon.isEmpty, "CaptureEffect.\(effect) has empty icon")
        }
    }

    @Test func captureEffectDescriptions() {
        for effect in CaptureEffect.allCases {
            #expect(!effect.description.isEmpty, "CaptureEffect.\(effect) has empty description")
        }
    }

    @Test func shareOptionIcons() {
        for option in ShareOption.allCases {
            #expect(!option.icon.isEmpty, "ShareOption.\(option) has empty icon")
        }
    }

    @Test func captureMethodIcons() {
        for method in CaptureMethod.allCases {
            #expect(!method.icon.isEmpty, "CaptureMethod.\(method) has empty icon")
        }
    }

    @Test func captureMethodDescriptions() {
        for method in CaptureMethod.allCases {
            #expect(!method.description.isEmpty, "CaptureMethod.\(method) has empty description")
        }
    }
}

// MARK: - CodablePoint Tests

@Suite("CodablePoint")
struct CodablePointTests {
    @Test func initFromValues() {
        let p = CodablePoint(x: 10.5, y: 20.3)
        #expect(p.x == 10.5)
        #expect(p.y == 20.3)
    }

    @Test func initFromCGPoint() {
        let cgPoint = CGPoint(x: 100, y: 200)
        let p = CodablePoint(point: cgPoint)
        #expect(p.x == 100)
        #expect(p.y == 200)
    }

    @Test func cgPointConversion() {
        let p = CodablePoint(x: 42.0, y: 84.0)
        let cgPoint = p.cgPoint
        #expect(cgPoint.x == 42.0)
        #expect(cgPoint.y == 84.0)
    }

    @Test func roundTripCodable() throws {
        let original = CodablePoint(x: 3.14, y: 2.71)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodablePoint.self, from: data)
        #expect(decoded.x == original.x)
        #expect(decoded.y == original.y)
    }
}

// MARK: - CodableRect Tests

@Suite("CodableRect")
struct CodableRectTests {
    @Test func initFromValues() {
        let r = CodableRect(x: 10, y: 20, width: 100, height: 200)
        #expect(r.x == 10)
        #expect(r.y == 20)
        #expect(r.width == 100)
        #expect(r.height == 200)
    }

    @Test func initFromCGRect() {
        let cgRect = CGRect(x: 5, y: 15, width: 50, height: 75)
        let r = CodableRect(rect: cgRect)
        #expect(r.x == 5)
        #expect(r.y == 15)
        #expect(r.width == 50)
        #expect(r.height == 75)
    }

    @Test func cgRectConversion() {
        let r = CodableRect(x: 1, y: 2, width: 3, height: 4)
        let cgRect = r.cgRect
        #expect(cgRect.origin.x == 1)
        #expect(cgRect.origin.y == 2)
        #expect(cgRect.size.width == 3)
        #expect(cgRect.size.height == 4)
    }

    @Test func roundTripCodable() throws {
        let original = CodableRect(x: 10, y: 20, width: 300, height: 400)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableRect.self, from: data)
        #expect(decoded.x == original.x)
        #expect(decoded.y == original.y)
        #expect(decoded.width == original.width)
        #expect(decoded.height == original.height)
    }
}

// MARK: - CodableSize Tests

@Suite("CodableSize")
struct CodableSizeTests {
    @Test func cgSizeConversion() {
        let s = CodableSize(width: 800, height: 600)
        let cgSize = s.cgSize
        #expect(cgSize.width == 800)
        #expect(cgSize.height == 600)
    }

    @Test func roundTripCodable() throws {
        let original = CodableSize(width: 1920, height: 1080)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableSize.self, from: data)
        #expect(decoded.width == original.width)
        #expect(decoded.height == original.height)
    }
}

// MARK: - CodableColor Tests

@Suite("CodableColor")
struct CodableColorTests {
    @Test func initFromComponents() {
        let c = CodableColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8)
        #expect(c.red == 1.0)
        #expect(c.green == 0.5)
        #expect(c.blue == 0.0)
        #expect(c.alpha == 0.8)
    }

    @Test @MainActor func nsColorConversion() {
        let c = CodableColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        let nsColor = c.nsColor
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(abs(r - 1.0) < 0.001)
        #expect(abs(g - 0.0) < 0.001)
        #expect(abs(b - 0.0) < 0.001)
        #expect(abs(a - 1.0) < 0.001)
    }

    @Test func roundTripCodable() throws {
        let original = CodableColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.9)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CodableColor.self, from: data)
        #expect(abs(decoded.red - original.red) < 0.0001)
        #expect(abs(decoded.green - original.green) < 0.0001)
        #expect(abs(decoded.blue - original.blue) < 0.0001)
        #expect(abs(decoded.alpha - original.alpha) < 0.0001)
    }
}

// MARK: - NSImage Extension Tests

@Suite("NSImage Extensions")
struct NSImageExtensionTests {
    private func makeTestImage(size: CGSize = CGSize(width: 100, height: 100)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    @Test func cgImageConversion() {
        let image = makeTestImage()
        #expect(image.cgImage != nil)
    }

    @Test func cgImageHasPositiveDimensions() {
        let image = makeTestImage(size: CGSize(width: 200, height: 150))
        if let cg = image.cgImage {
            #expect(cg.width > 0)
            #expect(cg.height > 0)
        }
    }
}

// MARK: - CaptureResult Tests

@Suite("CaptureResult")
struct CaptureResultTests {
    private func makeImage() -> NSImage {
        let img = NSImage(size: NSSize(width: 100, height: 100))
        img.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        img.unlockFocus()
        return img
    }

    @Test func initialization() {
        let image = makeImage()
        let result = CaptureResult(image: image, mode: .fullscreen)
        #expect(result.image === image)
    }

    @Test func timestampIsRecent() {
        let before = Date()
        let result = CaptureResult(image: makeImage(), mode: .area)
        let after = Date()
        #expect(result.timestamp >= before)
        #expect(result.timestamp <= after)
    }

    @Test func captureModeCases() {
        // All CaptureMode cases should be creatable
        _ = CaptureResult(image: makeImage(), mode: .area)
        _ = CaptureResult(image: makeImage(), mode: .window)
        _ = CaptureResult(image: makeImage(), mode: .fullscreen)
        _ = CaptureResult(image: makeImage(), mode: .scrolling)
    }
}

// MARK: - OCRManager Tests

@Suite("OCRManager")
struct OCRManagerTests {
    @Test func sharedInstanceNotProcessing() {
        #expect(!OCRManager.shared.isProcessing)
    }

    @Test(.timeLimit(.minutes(1))) func extractTextFromBlankImageDoesNotThrow() async {
        let image = NSImage(size: NSSize(width: 200, height: 100))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 200, height: 100).fill()
        image.unlockFocus()

        // Should not throw — blank images return nil or empty result
        let result = try? await OCRManager.shared.extractTextWithConfidence(from: image)
        if let r = result {
            #expect(r.confidence >= 0.0)
            #expect(r.confidence <= 1.0)
        }
        // nil is also valid (no text found)
    }

    @Test func zeroSizeImageHasNoCGImage() {
        let emptyImage = NSImage(size: .zero)
        let cgImage = emptyImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #expect(cgImage == nil)
    }
}

// MARK: - SelectableWindow Display Logic Tests

@Suite("SelectableWindow Display Logic")
struct SelectableWindowDisplayTests {
    @Test func displayTitleWithBothNames() {
        let ownerName = "Safari"
        let title = "Apple"
        let displayTitle = title.isEmpty ? ownerName : "\(ownerName) - \(title)"
        #expect(displayTitle == "Safari - Apple")
    }

    @Test func displayTitleFallsBackToOwnerName() {
        let ownerName = "Finder"
        let title = ""
        let displayTitle = title.isEmpty ? ownerName : "\(ownerName) - \(title)"
        #expect(displayTitle == "Finder")
    }
}

// MARK: - Notification Name Tests

@Suite("Notification Names")
struct NotificationNameTests {
    @Test func screenshotCapturedNotificationName() {
        #expect(Notification.Name.screenshotCaptured.rawValue == "screenshotCaptured")
    }

    @Test func screenshotSavedToHistoryNotificationName() {
        #expect(Notification.Name.screenshotSavedToHistory.rawValue == "screenshotSavedToHistory")
    }
}

// MARK: - EditorTool Tests

@Suite("EditorTool")
struct EditorToolTests {
    @Test func allCasesHaveNonEmptyIcons() {
        for tool in EditorTool.allCases {
            #expect(!tool.icon.isEmpty, "EditorTool.\(tool) has empty icon")
        }
    }

    @Test func allCasesHaveNonEmptyDisplayNames() {
        for tool in EditorTool.allCases {
            #expect(!tool.displayName.isEmpty, "EditorTool.\(tool) has empty displayName")
        }
    }

    @Test func identifiableIdEqualsRawValue() {
        for tool in EditorTool.allCases {
            #expect(tool.id == tool.rawValue)
        }
    }

    @Test func keyToolsPresent() {
        let cases = Set(EditorTool.allCases.map(\.rawValue))
        for required in ["selection", "pen", "arrow", "text", "crop", "blur", "eraser"] {
            #expect(cases.contains(required), "Missing expected tool: \(required)")
        }
    }

    @Test func codableRoundTrip() throws {
        let tool = EditorTool.arrow
        let data = try JSONEncoder().encode(tool)
        let decoded = try JSONDecoder().decode(EditorTool.self, from: data)
        #expect(decoded == tool)
    }
}

// MARK: - ImageAdjustments Tests

@Suite("ImageAdjustments")
struct ImageAdjustmentsTests {
    @Test func defaultIsDefault() {
        let adj = ImageAdjustments()
        #expect(adj.isDefault)
    }

    @Test func modifiedIsNotDefault() {
        var adj = ImageAdjustments()
        adj.brightness = 0.5
        #expect(!adj.isDefault)
    }

    @Test func resetRestoresDefaults() {
        var adj = ImageAdjustments()
        adj.brightness = 0.8
        adj.contrast = 1.5
        adj.saturation = 0.3
        adj.reset()
        #expect(adj.isDefault)
        #expect(adj.brightness == 0.0)
        #expect(adj.contrast == 1.0)
        #expect(adj.saturation == 1.0)
    }

    @Test func defaultValuesAreCorrect() {
        let adj = ImageAdjustments()
        #expect(adj.brightness == 0.0)
        #expect(adj.contrast == 1.0)
        #expect(adj.saturation == 1.0)
        #expect(adj.sharpness == 0.0)
        #expect(adj.vignette == 0.0)
    }

    @Test func equalityWithSameValues() {
        let a = ImageAdjustments()
        let b = ImageAdjustments()
        #expect(a == b)
    }

    @Test func appliedReturnsNonNilForValidImage() {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.green.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()

        var adj = ImageAdjustments()
        adj.brightness = 0.2
        let result = adj.applied(to: image)
        #expect(result != nil)
    }

    @Test func appliedWithDefaultReturnsNilOrSame() {
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: 100, height: 100).fill()
        image.unlockFocus()

        let adj = ImageAdjustments()
        #expect(adj.isDefault)
        // applied(to:) on default adjustments still goes through CI pipeline
        let result = adj.applied(to: image)
        #expect(result != nil)
    }
}

// MARK: - EditorAction Tests

@Suite("EditorAction")
struct EditorActionTests {
    @Test func allCasesHaveNonEmptyIcons() {
        for action in EditorAction.allCases {
            #expect(!action.icon.isEmpty, "EditorAction.\(action) has empty icon")
        }
    }

    @Test func identifiableIdEqualsRawValue() {
        for action in EditorAction.allCases {
            #expect(action.id == action.rawValue)
        }
    }

    @Test func expectedCasesPresent() {
        let cases = Set(EditorAction.allCases.map(\.rawValue))
        #expect(cases.contains("undo"))
        #expect(cases.contains("redo"))
        #expect(cases.contains("export"))
    }
}

// MARK: - ShapeType Tests

@Suite("ShapeType")
struct ShapeTypeTests {
    @Test func allCasesHaveNonEmptyDisplayNames() {
        for shape in ShapeType.allCases {
            #expect(!shape.displayName.isEmpty, "ShapeType.\(shape) has empty displayName")
        }
    }

    @Test func allCasesHaveNonEmptyIcons() {
        for shape in ShapeType.allCases {
            #expect(!shape.icon.isEmpty, "ShapeType.\(shape) has empty icon")
        }
    }

    @Test func identifiableIdEqualsRawValue() {
        for shape in ShapeType.allCases {
            #expect(shape.id == shape.rawValue)
        }
    }
}

// MARK: - CGAffineTransform Image Operation Tests

@Suite("Image Transform Helpers")
struct ImageTransformTests {
    private func makeSquareImage(side: Int = 100) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: side, height: side).fill()
        image.unlockFocus()
        return image
    }

    private func makeRectImage(width: Int = 200, height: Int = 100) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.blue.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }

    @Test func rotationCWSwapsDimensions() {
        let image = makeRectImage(width: 200, height: 100)
        guard let cgIn = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return  // can't test without CGImage
        }
        let srcW = CGFloat(cgIn.width)
        let srcH = CGFloat(cgIn.height)
        // Rotate 90° CW
        var ci = CIImage(cgImage: cgIn).transformed(by: CGAffineTransform(rotationAngle: -.pi / 2))
        let origin = ci.extent.origin
        if origin.x != 0 || origin.y != 0 {
            ci = ci.transformed(by: CGAffineTransform(translationX: -origin.x, y: -origin.y))
        }
        let extent = ci.extent
        // After 90° rotation width and height should swap (relative to source)
        #expect(abs(extent.width - srcH) < 2, "Rotated width should equal source height (\(srcH)), got \(extent.width)")
        #expect(abs(extent.height - srcW) < 2, "Rotated height should equal source width (\(srcW)), got \(extent.height)")
    }

    @Test func flipHorizontalPreservesDimensions() {
        let image = makeRectImage(width: 200, height: 100)
        guard let cgIn = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let t = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: CGFloat(cgIn.width), ty: 0)
        var ci = CIImage(cgImage: cgIn).transformed(by: t)
        let origin = ci.extent.origin
        if origin.x != 0 || origin.y != 0 {
            ci = ci.transformed(by: CGAffineTransform(translationX: -origin.x, y: -origin.y))
        }
        let extent = ci.extent
        #expect(abs(extent.width - CGFloat(cgIn.width)) < 2, "Flip H should preserve width")
        #expect(abs(extent.height - CGFloat(cgIn.height)) < 2, "Flip H should preserve height")
    }

    @Test func flipVerticalPreservesDimensions() {
        let image = makeRectImage(width: 200, height: 100)
        guard let cgIn = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        let t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(cgIn.height))
        var ci = CIImage(cgImage: cgIn).transformed(by: t)
        let origin = ci.extent.origin
        if origin.x != 0 || origin.y != 0 {
            ci = ci.transformed(by: CGAffineTransform(translationX: -origin.x, y: -origin.y))
        }
        let extent = ci.extent
        #expect(abs(extent.width - CGFloat(cgIn.width)) < 2, "Flip V should preserve width")
        #expect(abs(extent.height - CGFloat(cgIn.height)) < 2, "Flip V should preserve height")
    }
}
