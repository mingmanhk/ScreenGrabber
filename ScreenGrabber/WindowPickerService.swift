//
//  WindowPickerService.swift
//  ScreenGrabber
//
//  Service for picking windows
//

import Foundation
import AppKit

class WindowPickerService {
    static let shared = WindowPickerService()
    
    private init() {}
    
    struct WindowInfo {
        let windowID: CGWindowID
        let bounds: CGRect
        let ownerName: String?
        let windowName: String?
    }
    
    func getWindowAtPoint(_ point: CGPoint) -> WindowInfo? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        
        for windowDict in windowList {
            guard let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"],
                  let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }
            
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            
            if bounds.contains(point) {
                return WindowInfo(
                    windowID: windowID,
                    bounds: bounds,
                    ownerName: windowDict[kCGWindowOwnerName as String] as? String,
                    windowName: windowDict[kCGWindowName as String] as? String
                )
            }
        }
        
        return nil
    }
    
    func getAllWindows() -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        
        var windows: [WindowInfo] = []
        
        for windowDict in windowList {
            guard let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"],
                  let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }
            
            let bounds = CGRect(x: x, y: y, width: width, height: height)
            
            windows.append(WindowInfo(
                windowID: windowID,
                bounds: bounds,
                ownerName: windowDict[kCGWindowOwnerName as String] as? String,
                windowName: windowDict[kCGWindowName as String] as? String
            ))
        }
        
        return windows
    }
}
