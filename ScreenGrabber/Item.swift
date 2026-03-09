//
//  Item.swift
//  ScreenGrabber
//
//  SwiftData model for storing screenshot metadata
//  Created on 01/03/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var fileURL: String
    var fileName: String
    var captureMethod: String
    var fileSize: Int64
    var imageWidth: Int
    var imageHeight: Int
    var tags: [String]
    
    init(timestamp: Date = Date(),
         fileURL: String,
         fileName: String,
         captureMethod: String = "unknown",
         fileSize: Int64 = 0,
         imageWidth: Int = 0,
         imageHeight: Int = 0,
         tags: [String] = []) {
        self.timestamp = timestamp
        self.fileURL = fileURL
        self.fileName = fileName
        self.captureMethod = captureMethod
        self.fileSize = fileSize
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.tags = tags
    }
}
