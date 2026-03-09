import Foundation
import AVFoundation
import CoreMedia
import CoreGraphics
import CoreVideo

#if canImport(ScreenCaptureKit)
import ScreenCaptureKit
#endif

/// Utility to check/trigger macOS Screen Recording permission.
///
/// Usage:
///   - Call `ScreenRecordingPermission.ensureAuthorized()` from the moment the user starts screen capture.
///   - If permission isn't granted yet, macOS will prompt and list your app under Privacy & Security > Screen Recording.
///   - No Info.plist key is required for Screen Recording.
enum ScreenRecordingPermission {
    private static var avCaptureDelegate: AVSampleBufferSink?

    /// Attempts to start a minimal capture to trigger the system prompt if needed, then stops.
    /// Call this right before you begin your real capture flow.
    static func ensureAuthorized() {
        // If the user previously denied, starting capture will still prompt them to enable in Settings.
        // We attempt a minimal capture and stop immediately after the pipeline initializes.
        if #available(macOS 12.3, *), canUseScreenCaptureKit {
            startStopWithScreenCaptureKit()
        } else {
            startStopWithAVFoundation()
        }
    }

    // MARK: - ScreenCaptureKit path (macOS 12.3+)
    @available(macOS 12.3, *)
    private static var canUseScreenCaptureKit: Bool {
        #if canImport(ScreenCaptureKit)
        return true
        #else
        return false
        #endif
    }

    @available(macOS 12.3, *)
    private static func startStopWithScreenCaptureKit() {
        #if canImport(ScreenCaptureKit)
        // Pick the main display and start a short capture session
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.current
                guard let display = content.displays.first else { return }

                let filter = SCContentFilter(display: display, excludingWindows: [])
                let streamConfig = SCStreamConfiguration()
                streamConfig.queueDepth = 1
                streamConfig.capturesAudio = false
                streamConfig.pixelFormat = kCVPixelFormatType_32BGRA
                streamConfig.width = Int(display.width)
                streamConfig.height = Int(display.height)

                let stream = SCStream(filter: filter, configuration: streamConfig, delegate: nil)
                let sampleHandler = SampleBufferSink { _ in }
                try stream.addStreamOutput(sampleHandler, type: .screen, sampleHandlerQueue: .main)

                try await stream.start()
                // Stop almost immediately to avoid consuming resources
                try await Task.sleep(nanoseconds: 150_000_000) // 0.15s
                try await stream.stop()
            } catch {
                // Errors here likely indicate lack of permission or user denial; the system will guide the user.
                NSLog("ScreenCaptureKit start/stop error: \(error.localizedDescription)")
            }
        }
        #endif
    }

    // MARK: - AVFoundation fallback (older macOS)
    private static func startStopWithAVFoundation() {
        // Minimal AVCaptureSession with AVCaptureScreenInput
        let session = AVCaptureSession()
        session.sessionPreset = .low

        let mainDisplayID = CGMainDisplayID()
        guard let input = AVCaptureScreenInput(displayID: mainDisplayID) else {
            return
        }
        input.capturesMouseClicks = false
        input.capturesCursor = false

        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        let queue = DispatchQueue(label: "ScreenRecordingPermission.AVQueue")
        self.avCaptureDelegate = AVSampleBufferSink { _ in }
        output.setSampleBufferDelegate(self.avCaptureDelegate, queue: queue)

        session.startRunning()
        // Stop shortly after to avoid resource usage
        queue.asyncAfter(deadline: .now() + 0.15) {
            session.stopRunning()
            self.avCaptureDelegate = nil
        }
    }
}

// MARK: - Helpers

#if canImport(ScreenCaptureKit)
@available(macOS 12.3, *)
private final class SampleBufferSink: NSObject, SCStreamOutput {
    private let handler: (CMSampleBuffer) -> Void
    init(_ handler: @escaping (CMSampleBuffer) -> Void) { self.handler = handler }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        handler(sampleBuffer)
    }
}
#endif

private final class AVSampleBufferSink: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let handler: (CMSampleBuffer) -> Void
    init(_ handler: @escaping (CMSampleBuffer) -> Void) { self.handler = handler }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        handler(sampleBuffer)
    }
}

