// ScreenCaptureButton.swift
// A SwiftUI wrapper that ensures Screen Recording permission is triggered
// right before starting the actual capture.

import SwiftUI

public struct ScreenCaptureButton<Label: View>: View {
    private let action: () -> Void
    private let label: () -> Label

    public init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }

    public var body: some View {
        Button(action: {
            // Trigger Screen Recording permission if needed
            ScreenRecordingPermission.ensureAuthorized()
            // Proceed with the caller's capture logic
            action()
        }, label: label)
    }
}

#if DEBUG
#Preview("ScreenCaptureButton") {
    ScreenCaptureButton(action: {
        // Your capture logic goes here
        print("Start capture pressed")
    }) {
        Text("Start Screen Capture")
    }
    .padding()
}
#endif
