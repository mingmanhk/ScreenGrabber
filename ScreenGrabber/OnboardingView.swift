//
//  OnboardingView.swift
//  ScreenGrabber
//
//  Created on 01/17/26.
//  First-launch onboarding experience
//

import SwiftUI

/// Main onboarding window container
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep: OnboardingStep = .welcome
    @State private var model = OnboardingModel.shared
    @State private var animateContent = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            OnboardingProgressView(currentStep: currentStep)
                .padding(.top, 20)
            
            // Content area
            ZStack {
                ForEach(OnboardingStep.allCases, id: \.self) { step in
                    if currentStep == step {
                        stepView(for: step)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.3), value: currentStep)
            
            // Navigation buttons
            OnboardingNavigationView(
                currentStep: $currentStep,
                onComplete: completeOnboarding
            )
            .padding(.horizontal, 30)
            .padding(.bottom, 20)
        }
        .frame(width: 600, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                animateContent = true
            }
        }
    }
    
    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeStepView(isAnimated: animateContent)
        case .permissions:
            PermissionsStepView()
        case .saveLocation:
            SaveLocationStepView()
        case .quickTour:
            QuickTourStepView()
        case .complete:
            CompleteStepView()
        }
    }
    
    private func completeOnboarding() {
        model.completeOnboarding()
        
        // Show success notification
        ScreenCaptureManager.shared.showNotification(
            title: "Ready to Capture",
            message: "Screen Grabber is ready to use. Click the menu bar icon to get started."
        )
        
        dismiss()
    }
}

// MARK: - Progress Indicator

struct OnboardingProgressView: View {
    let currentStep: OnboardingStep
    
    private let totalSteps = OnboardingStep.allCases.count - 1 // Exclude complete
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    ProgressDot(
                        isActive: index == currentStep.rawValue,
                        isCompleted: index < currentStep.rawValue
                    )
                }
            }
            
            Text("Step \(currentStep.rawValue + 1) of \(totalSteps)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 20)
    }
}

struct ProgressDot: View {
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.accentColor : Color.secondary.opacity(0.2))
                .frame(width: 10, height: 10)
            
            if isActive {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2)
                    .frame(width: 18, height: 18)
            }
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isActive)
        .animation(.easeInOut(duration: 0.2), value: isCompleted)
    }
}

// MARK: - Navigation

struct OnboardingNavigationView: View {
    @Binding var currentStep: OnboardingStep
    let onComplete: () -> Void
    
    private var canGoBack: Bool {
        currentStep.rawValue > 0 && currentStep != .complete
    }
    
    private var nextButtonTitle: String {
        if currentStep == .complete {
            return "Get Started"
        } else if currentStep.rawValue == OnboardingStep.allCases.count - 2 {
            return "Finish"
        } else {
            return "Continue"
        }
    }
    
    var body: some View {
        HStack {
            // Skip button
            if currentStep != .complete && currentStep != .permissions {
                Button("Skip Setup") {
                    withAnimation {
                        currentStep = .complete
                    }
                }
                .keyboardShortcut(.cancelAction)
            }
            
            Spacer()
            
            // Back button
            if canGoBack {
                Button("Back") {
                    goBack()
                }
            }
            
            // Next/Complete button
            Button(nextButtonTitle) {
                nextStep()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
    }
    
    private func goBack() {
        withAnimation {
            if let previousStep = OnboardingStep(rawValue: currentStep.rawValue - 1) {
                currentStep = previousStep
            }
        }
    }
    
    private func nextStep() {
        if currentStep == .complete {
            onComplete()
        } else {
            withAnimation {
                if let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) {
                    currentStep = nextStep
                }
            }
        }
    }
}

// MARK: - Step Views

struct WelcomeStepView: View {
    let isAnimated: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // App icon
            Image(systemName: "camera.metering.matrix")
                .font(.system(size: 80))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .symbolEffect(.bounce, value: isAnimated)
            
            // Title
            Text("Welcome to Screen Grabber")
                .font(.system(size: 32, weight: .bold))
            
            // Subtitle
            Text("Capture, edit, and share screenshots with ease")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "rectangle.dashed",
                    title: "Flexible Capture",
                    description: "Capture areas, windows, or entire screens"
                )
                
                FeatureRow(
                    icon: "pencil.tip.crop.circle",
                    title: "Built-in Editor",
                    description: "Annotate and edit your screenshots instantly"
                )
                
                FeatureRow(
                    icon: "arrow.down.doc",
                    title: "Smart Scrolling",
                    description: "Capture long pages with automatic scrolling"
                )
                
                FeatureRow(
                    icon: "square.and.arrow.up",
                    title: "Easy Sharing",
                    description: "Copy, save, or share with a single click"
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(30)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PermissionsStepView: View {
    @State private var model = OnboardingModel.shared
    @State private var checkTimer: Timer?
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
            
            // Title
            Text("Set Up Permissions")
                .font(.system(size: 28, weight: .bold))
            
            // Subtitle
            Text("Screen Grabber needs these permissions to function properly")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Permission cards
            VStack(spacing: 16) {
                PermissionCard(
                    title: "Screen Recording",
                    description: "Required to capture screenshots and recordings",
                    icon: "rectangle.on.rectangle",
                    isGranted: model.screenRecordingPermissionGranted,
                    isRequired: true,
                    onRequest: {
                        model.requestScreenRecordingPermission()
                        startPermissionCheck()
                    },
                    onOpenSettings: {
                        model.openSystemSettings(for: .screenRecording)
                        startPermissionCheck()
                    }
                )
                
                PermissionCard(
                    title: "Accessibility",
                    description: "Required for window selection and smart capture features",
                    icon: "accessibility",
                    isGranted: model.accessibilityPermissionGranted,
                    isRequired: true,
                    onRequest: {
                        model.requestAccessibilityPermission()
                        startPermissionCheck()
                    },
                    onOpenSettings: {
                        model.openSystemSettings(for: .accessibility)
                        startPermissionCheck()
                    }
                )
                
                PermissionCard(
                    title: "Full Disk Access",
                    description: "Optional - Needed for Desktop/Documents folders",
                    icon: "externaldrive.fill",
                    isGranted: model.fullDiskAccessGranted,
                    isRequired: false,
                    onRequest: {
                        model.requestFullDiskAccessPermission()
                        startPermissionCheck()
                    },
                    onOpenSettings: {
                        model.openSystemSettings(for: .fullDiskAccess)
                        startPermissionCheck()
                    }
                )
            }
            .padding(.horizontal, 40)
            
            if model.allRequiredPermissionsGranted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Required permissions granted!")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                .padding(.top, 8)
                
                if !model.fullDiskAccessGranted {
                    Text("Full Disk Access is optional but recommended if you plan to save to Desktop or Documents")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
        }
        .padding(30)
        .onAppear {
            startPermissionCheck()
        }
        .onDisappear {
            stopPermissionCheck()
        }
    }
    
    private func startPermissionCheck() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [model] _ in
            // Force UI update by updating the model's permissions
            Task { @MainActor in
                _ = model.screenRecordingPermissionGranted
                _ = model.accessibilityPermissionGranted
                _ = model.fullDiskAccessGranted
            }
        }
    }
    
    private func stopPermissionCheck() {
        checkTimer?.invalidate()
        checkTimer = nil
    }
}

struct PermissionCard: View {
    let title: String
    let description: String
    let icon: String
    let isGranted: Bool
    let isRequired: Bool
    let onRequest: () -> Void
    let onOpenSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(isGranted ? .green : .secondary)
                .frame(width: 40)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)
                    if !isRequired {
                        Text("OPTIONAL")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.6))
                            .clipShape(Capsule())
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Status/Action
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Menu {
                    Button("Request Permission") {
                        onRequest()
                    }
                    Button("Open System Settings") {
                        onOpenSettings()
                    }
                } label: {
                    Text("Grant")
                        .frame(width: 80)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct SaveLocationStepView: View {
    @State private var settings = SettingsModel.shared
    @State private var model = OnboardingModel.shared
    @State private var showingFolderPicker = false
    
    private var currentLocation: String {
        if settings.saveFolderPath.isEmpty {
            return "~/Pictures/Screen Grabber/"
        } else {
            return settings.saveFolderPath
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "folder.fill")
                .font(.system(size: 60))
                .foregroundStyle(.purple)
            
            // Title
            Text("Choose Save Location")
                .font(.system(size: 28, weight: .bold))
            
            // Subtitle
            Text("Select where your screenshots will be saved")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // Current location
            VStack(spacing: 16) {
                HStack {
                    Text("Current Location:")
                        .font(.headline)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    
                    Text(currentLocation)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer()
                    
                    Button("Change…") {
                        chooseSaveFolder()
                    }
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 60)
            
            // Info
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(
                    icon: "checkmark.circle",
                    title: "Organized by date",
                    description: "Screenshots are organized by date"
                )
                FeatureRow(
                    icon: "checkmark.circle",
                    title: "Change anytime",
                    description: "You can change this location anytime in Settings"
                )
                FeatureRow(
                    icon: "checkmark.circle",
                    title: "Auto-created",
                    description: "The folder will be created automatically if needed"
                )
            }
            .padding(.horizontal, 60)
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(30)
    }
    
    private func chooseSaveFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for saving screenshots"
        panel.prompt = "Select"
        
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolderPath = url.path
            model.hasConfiguredSaveLocation = true
            
            ScreenCaptureManager.shared.showNotification(
                title: "Save Location Updated",
                message: "Screenshots will be saved to \(url.lastPathComponent)"
            )
        }
    }
}

private struct OnboardingInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.green)
                .font(.caption)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct QuickTourStepView: View {
    @State private var currentTourStep = 0
    private let tourSteps = TourStep.allSteps
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            
            // Title
            Text("Quick Tour")
                .font(.system(size: 28, weight: .bold))
            
            // Subtitle
            Text("Learn the basics in 60 seconds")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Tour content
            TabView(selection: $currentTourStep) {
                ForEach(Array(tourSteps.enumerated()), id: \.offset) { index, step in
                    TourStepCard(step: step)
                        .tag(index)
                }
            }
            // Note: .tabViewStyle(.page) and .indexViewStyle are iOS-only
            // macOS uses standard tab view appearance
            .frame(height: 220)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(30)
    }
}

struct TourStep {
    let icon: String
    let title: String
    let description: String
    let shortcut: String?
    
    static let allSteps: [TourStep] = [
        TourStep(
            icon: "cursorarrow.click.2",
            title: "Start a Capture",
            description: "Click the menu bar icon and choose your capture type: Area, Window, or Full Screen",
            shortcut: "⌘⇧5"
        ),
        TourStep(
            icon: "arrow.up.left.and.arrow.down.right",
            title: "Select Your Area",
            description: "Click and drag to select the area you want to capture. Press Space to switch between area and window selection",
            shortcut: "Space"
        ),
        TourStep(
            icon: "pencil.tip.crop.circle",
            title: "Edit Your Screenshot",
            description: "Use the built-in editor to add arrows, text, shapes, and highlights to your captures",
            shortcut: nil
        ),
        TourStep(
            icon: "square.and.arrow.up",
            title: "Save or Share",
            description: "Copy to clipboard, save to disk, or share directly. Your captures are automatically organized by date",
            shortcut: "⌘C / ⌘S"
        )
    ]
}

struct TourStepCard: View {
    let step: TourStep
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: step.icon)
                .font(.system(size: 40))
                .foregroundStyle(.blue)
            
            Text(step.title)
                .font(.title3.bold())
            
            Text(step.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            if let shortcut = step.shortcut {
                HStack(spacing: 6) {
                    Text("Shortcut:")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(shortcut)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
    }
}

struct CompleteStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated checkmark
            ZStack {
                Circle()
                    .fill(.green.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.green)
            }
            
            // Title
            Text("You're All Set!")
                .font(.system(size: 32, weight: .bold))
            
            // Subtitle
            Text("Screen Grabber is ready to capture amazing screenshots")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Quick tips
            VStack(alignment: .leading, spacing: 12) {
                QuickTip(
                    icon: "menubar.rectangle",
                    text: "Access Screen Grabber from the menu bar"
                )
                QuickTip(
                    icon: "command",
                    text: "Press ⌘⇧5 to start a quick capture"
                )
                QuickTip(
                    icon: "gearshape",
                    text: "Customize settings anytime from the menu"
                )
            }
            .padding(.horizontal, 60)
            
            Spacer()
        }
        .padding(30)
    }
}

struct QuickTip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
