//
//  Screenshot.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import Foundation
import SwiftData

@Model
final class Screenshot {
    var filename: String
    var filePath: String
    var captureDate: Date
    var captureMethod: String // "selected_area", "window", "full_screen", "scrolling_capture"
    var openMethod: String // "clipboard", "save_to_file", "preview"
    
    init(filename: String, filePath: String, captureDate: Date, captureMethod: String, openMethod: String) {
        self.filename = filename
        self.filePath = filePath
        self.captureDate = captureDate
        self.captureMethod = captureMethod
        self.openMethod = openMethod
    }
}