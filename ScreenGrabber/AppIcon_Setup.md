# App Icon Setup Instructions

## Setting up the App Icon in Xcode

1. **Open your project in Xcode**
2. **Navigate to the Asset Catalog**:
   - In the Project Navigator, look for `Assets.xcassets`
   - If it doesn't exist, create it: Right-click your project folder → "New File" → "Asset Catalog"

3. **Create/Configure App Icon**:
   - In `Assets.xcassets`, look for "AppIcon" 
   - If it doesn't exist, right-click and select "New Image Set" → rename to "AppIcon"
   - Select "AppIcon" and in the Attributes Inspector, change "Type" to "App Icon"

4. **Add Icon Images**:
   You need different sizes for macOS. The most important ones are:
   - **16x16** (icon_16x16.png and icon_16x16@2x.png - 32x32)
   - **32x32** (icon_32x32.png and icon_32x32@2x.png - 64x64) 
   - **128x128** (icon_128x128.png and icon_128x128@2x.png - 256x256)
   - **256x256** (icon_256x256.png and icon_256x256@2x.png - 512x512)
   - **512x512** (icon_512x512.png and icon_512x512@2x.png - 1024x1024)

5. **Set the App Icon in Project Settings**:
   - Select your project in the Navigator
   - Go to your app target
   - In the "General" tab, under "App Icons and Launch Screen"
   - Set "App Icon" to "AppIcon"

## Quick Fix: Use SF Symbols as App Icon

If you don't have custom icons, you can create a simple programmatic icon:

```swift
// Add this function to create a simple app icon
private func createAppIcon() -> NSImage {
    let size = NSSize(width: 512, height: 512)
    let image = NSImage(size: size)
    
    image.lockFocus()
    defer { image.unlockFocus() }
    
    // Draw a camera icon using SF Symbols
    let icon = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 300, weight: .medium))
    
    if let icon = icon {
        let rect = CGRect(x: (size.width - icon.size.width) / 2,
                         y: (size.height - icon.size.height) / 2,
                         width: icon.size.width,
                         height: icon.size.height)
        icon.draw(in: rect)
    }
    
    return image
}
```

## Current Implementation

The app now uses:
- **Menu bar icon**: Custom-drawn camera icon with proper fallback
- **Button icon**: SF Symbols `camera.viewfinder` 
- **Menu bar behavior**: Template rendering (adapts to system appearance)

The menu bar icon should now be visible and properly styled according to the system appearance (light/dark mode).