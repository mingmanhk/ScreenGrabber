//
//  Item.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
