//
//  SettingsManager.swift
//  ScreenGrabber
//
//  Created by Screen Grabber Team on 11/28/25.
//

import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // MARK: - Capture Settings
    @AppStorage("selectedScreenOption") var selectedScreenOption: ScreenOption = .selectedArea
    @AppStorage("selectedOpenOption") var selectedOpenOption: OpenOption = .saveToFile
    @AppStorage("captureDelay") var captureDelay: Double = 0.0
    
    // MARK: - OCR / AI Settings
    @AppStorage("autoCopyText") var autoCopyText: Bool = false
    @AppStorage("ocrEnabled") var ocrEnabled: Bool = true
    @AppStorage("smartNamingEnabled") var smartNamingEnabled: Bool = false
    @AppStorage("autoRedactionEnabled") var autoRedactionEnabled: Bool = false
    
    // MARK: - Editor Settings
    @AppStorage("defaultAnnotationColor") var defaultAnnotationColor: String = "red"
    @AppStorage("showGrid") var showGrid: Bool = false
    
    private init() {}
}
