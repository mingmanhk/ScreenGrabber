# ScreenGrabber

<div align="center">

![ScreenGrabber Icon](https://img.shields.io/badge/macOS-Compatible-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Latest-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

**A powerful, modern macOS screenshot application with global hotkey support and intelligent organization.**

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Documentation](#-documentation) • [Support](#-support)

</div>

---

## 📸 Overview

ScreenGrabber is a native macOS application that revolutionizes how you capture, organize, and manage screenshots. Built with SwiftUI and modern Apple technologies, it provides a seamless experience right from your menu bar.

## ✨ Features

## ✨ Features

### 🎯 **Smart Screenshot Capture**
- **Multiple Capture Methods:**
  - 📐 **Selected Area** - Precisely capture any region of your screen
  - 🪟 **Window Capture** - Grab specific windows with a single click
  - 🖥️ **Full Screen** - Capture your entire display
  - 📜 **Scrolling Capture** - Perfect for long documents
  
- **Flexible Output Options:**
  - 📋 **Clipboard** - Instantly copy to clipboard for quick pasting
  - 💾 **Save to File** - Automatically organize in your library
  - 👁️ **Preview** - Open immediately for editing or annotation

### ⌨️ **Global Hotkey System**
- **Customizable Shortcuts** - Set your preferred key combinations
- **System-Wide Access** - Works from any application
- **Default Hotkey:** `⌘⇧C` (Command + Shift + C)
- **Instant Response** - Lightning-fast capture triggering
- **Persistent Settings** - Your preferences survive app restarts

### 🗂️ **Intelligent Organization**
- **Automatic File Management** - All screenshots saved to `~/Pictures/ScreenGrabber/`
- **Smart Naming** - Timestamped files: `Screenshot_YYYY-MM-DD_HH-mm-ss.png`
- **Search & Filter** - Quickly find screenshots by name
- **Sort Options** - Organize by date (newest/oldest) or name (A-Z)
- **Grid View** - Adjustable thumbnail sizes (Large/Medium/Small)

### 🎨 **Modern User Interface**
- **Menu Bar Integration** - Quick access without cluttering your dock
- **Beautiful Browser View** - Full-featured screenshot library
- **Live Preview** - See thumbnails as you browse
- **Hover Actions** - View, edit, or delete with intuitive controls
- **Dark Mode Support** - Seamlessly adapts to your system theme

### 📊 **Statistics & Insights**
- **Total Screenshots** - Track your capture count
- **Storage Usage** - Monitor total file size
- **Recent Activity** - Quick access to latest captures
- **Relative Timestamps** - "2 min ago" style dates

### 🔧 **Advanced Features**
- **Context Menu Support** - Right-click for quick actions
- **Copy to Clipboard** - Directly from the browser
- **Show in Finder** - Navigate to files instantly
- **Batch Operations** - Delete multiple screenshots
- **SwiftData Integration** - Modern data persistence

## 🖥️ System Requirements

- **macOS:** 13.0 (Ventura) or later
- **Architecture:** Apple Silicon (M1/M2/M3) or Intel
- **Permissions Required:**
  - Screen Recording
  - Accessibility (for global hotkeys)
  - Notifications (optional)

## 📦 Installation

### Option 1: Build from Source

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/ScreenGrabber.git
   cd ScreenGrabber
   ```

2. **Open in Xcode:**
   ```bash
   open ScreenGrabber.xcodeproj
   ```

3. **Build and Run:**
   - Select your target Mac
   - Press `⌘R` or click the Run button
   - Grant permissions when prompted

### Option 2: Download Release

1. Visit the [Releases](https://github.com/yourusername/ScreenGrabber/releases) page
2. Download the latest `.dmg` file
3. Open the DMG and drag ScreenGrabber to Applications
4. Launch from Applications folder

## 🚀 Usage

### First Launch Setup

1. **Launch ScreenGrabber** from Applications or Spotlight
2. **Grant Permissions:**
   - Click "Open System Preferences" when prompted
   - Enable **Screen Recording** permission
   - Enable **Accessibility** permission (for hotkeys)
3. **Configure Your Preferences:**
   - Choose your preferred capture method
   - Set your output destination
   - Customize your global hotkey

### Quick Start Guide

#### Taking Screenshots

**Method 1: Global Hotkey (Fastest)**
```
1. Press ⌘⇧C (or your custom hotkey) anywhere in macOS
2. Follow the on-screen instructions for your selected method
3. Screenshot automatically saved to your library
```

**Method 2: Menu Bar**
```
1. Click the ScreenGrabber icon in menu bar
2. Select capture method (Area/Window/Full Screen)
3. Choose output option (Clipboard/File/Preview)
4. Click "Capture Screenshot" button
```

**Method 3: Browser Window**
```
1. Open ScreenGrabber from menu bar
2. Click "Capture Screenshot" in the floating action bar
3. Or use the prominent capture button in empty state
```

### Managing Your Screenshots

#### Browsing Your Library
- Open the main window to see all screenshots
- Use the search bar to filter by filename
- Sort by date or name using the toolbar menu
- Adjust grid size for optimal viewing

#### Screenshot Actions
- **View:** Click the eye icon or double-click thumbnail
- **Edit:** Click the pencil icon to open editor
- **Delete:** Click the trash icon to remove
- **Copy:** Right-click → Copy to clipboard
- **Reveal:** Right-click → Show in Finder

### Customizing Settings

#### Capture Settings
```
Sidebar → Capture → Screen Method
- Selected Area: Drag to select region
- Window: Click to capture window
- Full Screen: Instant full display capture
- Scrolling: For long pages (experimental)
```

#### Output Settings
```
Sidebar → Capture → Output Method
- Clipboard: Copy + Save
- Save to File: Save only
- Preview: Open in Preview app
```

#### Hotkey Configuration
```
Sidebar → Quick Actions → Global Hotkey
- Choose from presets
- Or create custom combination
- Supports ⌘⇧⌥⌃ + any letter
```

## 📚 Documentation

### File Structure

```
ScreenGrabber/
├── App/
│   ├── ScreenGrabberApp.swift      # Main app entry point
│   └── AppDelegate.swift           # Menu bar coordination
├── Views/
│   ├── ScreenshotBrowserView.swift # Main browser interface
│   ├── MenuBarContentView.swift    # Menu bar popover
│   ├── SimpleImageEditorView.swift # Image editing
│   └── HotkeyConfigView.swift      # Hotkey configuration
├── Managers/
│   ├── ScreenCaptureManager.swift  # Screenshot operations
│   └── GlobalHotkeyManager.swift   # Hotkey handling
├── Models/
│   ├── Screenshot.swift            # SwiftData model
│   └── Item.swift                  # Legacy support
└── Resources/
    ├── Assets.xcassets             # Icons and images
    └── Info.plist                  # App configuration
```

### Key Components

#### ScreenCaptureManager
Handles all screenshot operations:
- Executes `screencapture` command
- Manages file saving and naming
- Handles permissions
- Provides recent screenshots

#### GlobalHotkeyManager
Manages system-wide keyboard shortcuts:
- Uses Carbon framework for reliability
- Registers/unregisters hotkeys
- Triggers capture on activation
- Persists hotkey preferences

#### ScreenshotBrowserView
Main user interface:
- Grid-based screenshot library
- Search and sort functionality
- Hover actions and context menus
- Modern, responsive design

### Architecture

```
┌─────────────────────┐
│   ScreenGrabberApp  │
│   (App Entry Point) │
└──────────┬──────────┘
           │
    ┌──────┴───────┐
    │              │
┌───▼────┐    ┌───▼─────────────┐
│ Menu   │    │ Main Window     │
│ Bar    │    │ (Browser View)  │
└───┬────┘    └───┬─────────────┘
    │             │
    └──────┬──────┘
           │
    ┌──────▼──────────────┐
    │ ScreenCaptureManager│
    │ GlobalHotkeyManager │
    └─────────────────────┘
```

## 🎨 Design Philosophy

ScreenGrabber follows Apple's Human Interface Guidelines and modern design principles:

- **Clarity:** Clean, intuitive interface with clear visual hierarchy
- **Consistency:** Unified design language across all views
- **Efficiency:** Minimal clicks to accomplish tasks
- **Beauty:** Gradient accents, smooth animations, thoughtful spacing
- **Accessibility:** Keyboard shortcuts, tooltips, semantic colors

## 🔧 Advanced Configuration

### Custom Screenshot Folder

By default, screenshots are saved to `~/Pictures/ScreenGrabber/`. To customize:

```swift
// In ScreenCaptureManager.swift
func getScreenGrabberFolderURL() -> URL {
    let picturesURL = FileManager.default.urls(
        for: .picturesDirectory, 
        in: .userDomainMask
    ).first!
    return picturesURL.appendingPathComponent("YourCustomFolder")
}
```

### Hotkey Modifiers

Supported modifier keys:
- `⌘` Command (cmdKey)
- `⇧` Shift (shiftKey)
- `⌥` Option/Alt (optionKey)
- `⌃` Control (controlKey)

Combine any modifiers with letters A-Z or numbers 0-9.

## 🐛 Troubleshooting
## 🐛 Troubleshooting

### Common Issues

#### Hotkeys Not Working

**Problem:** Global hotkey doesn't trigger screenshots

**Solutions:**
1. Check Accessibility permissions:
   ```
   System Settings → Privacy & Security → Accessibility
   → Enable ScreenGrabber
   ```
2. Restart the app
3. Try a different hotkey combination
4. Ensure no conflicts with other apps

#### Screenshots Not Saving

**Problem:** Screenshots aren't appearing in the folder

**Solutions:**
1. Verify Screen Recording permission:
   ```
   System Settings → Privacy & Security → Screen Recording
   → Enable ScreenGrabber
   ```
2. Check folder permissions:
   ```bash
   ls -la ~/Pictures/ScreenGrabber/
   ```
3. Manually create folder if needed:
   ```bash
   mkdir -p ~/Pictures/ScreenGrabber
   ```

#### App Icon Missing from Menu Bar

**Problem:** Can't find the app in menu bar

**Solutions:**
1. Check if app is running in Activity Monitor
2. Restart the application
3. Check menu bar isn't hidden
4. Look for "G" icon in right side of menu bar

#### Performance Issues

**Problem:** App feels slow or unresponsive

**Solutions:**
1. Clear old screenshots from library
2. Restart the app
3. Check available disk space
4. Reduce grid size in browser view

### Getting Help

- **Documentation:** Check this README first
- **Issues:** [GitHub Issues](https://github.com/yourusername/ScreenGrabber/issues)
- **Discussions:** [GitHub Discussions](https://github.com/yourusername/ScreenGrabber/discussions)
- **Email:** support@screengrabber.app

## 🤝 Contributing

We welcome contributions! Here's how to get started:

### Development Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/yourusername/ScreenGrabber.git
   ```
3. Create a feature branch:
   ```bash
   git checkout -b feature/amazing-feature
   ```
4. Make your changes
5. Test thoroughly
6. Commit with clear messages:
   ```bash
   git commit -m "Add: Amazing new feature"
   ```
7. Push to your fork:
   ```bash
   git push origin feature/amazing-feature
   ```
8. Open a Pull Request

### Coding Guidelines

- Follow Swift style guidelines
- Use SwiftUI best practices
- Add comments for complex logic
- Include tests where applicable
- Update documentation as needed

### Areas for Contribution

- 🐛 Bug fixes
- ✨ New features
- 📝 Documentation improvements
- 🎨 UI/UX enhancements
- 🌐 Localization
- ♿ Accessibility improvements

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 ScreenGrabber

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

## 🙏 Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/) and [SwiftData](https://developer.apple.com/xcode/swiftdata/)
- Uses macOS native `screencapture` command
- Inspired by modern screenshot tools
- Thanks to all contributors!

## 📞 Support

### Get Help

- 📖 [Documentation](https://github.com/yourusername/ScreenGrabber/wiki)
- 💬 [Discord Community](https://discord.gg/screengrabber)
- 🐦 [Twitter @ScreenGrabber](https://twitter.com/screengrabber)
- 📧 Email: support@screengrabber.app

### Report Issues

Found a bug? [Open an issue](https://github.com/yourusername/ScreenGrabber/issues/new) with:
- macOS version
- ScreenGrabber version
- Steps to reproduce
- Expected vs actual behavior
- Screenshots if applicable

## 🗺️ Roadmap & Enhancement Ideas

### ✅ Version 2.0 Features (COMPLETED!)

The following features are now fully implemented and available:

- ✅ **Capture Delay Timer** - 3s, 5s, 10s countdown options
- ✅ **Auto-Copy Filename/Path** - Automatic clipboard copying after capture
- ✅ **Floating Thumbnail Preview** - Pin screenshots on screen with quick actions
- ✅ **Region Presets** - Save and reuse custom capture areas
- ✅ **Image Compression Profiles** - Multiple format options (PNG, JPEG, HEIF)
- ✅ **Automatic Organization** - Smart folder rules for auto-sorting
- ✅ **Quick Actions Bar** - Post-capture HUD with customizable actions
- ✅ **Enhanced Settings Panel** - Comprehensive configuration options

**See IMPLEMENTATION_GUIDE.md for complete documentation.**

---

### 🚀 Version 2.5 (Next - 6 months)
- [ ] Quick Draw on Capture - Instant markup overlay
- [ ] Smart Tags - Automatic and manual tagging system
- [ ] Project Workspaces - Organize screenshots by project
- [ ] Multi-Monitor Control - Advanced display selection
- [ ] Auto-Trim / Smart Crop - Automatic edge cleanup

### 🎯 Version 3.0 (Future - 12 months)
- [ ] Cloud sync support
- [ ] Advanced image editing suite
- [ ] Screenshot annotations with collaboration
- [ ] OCR text extraction and search
- [ ] Quick Share extensions
- [ ] Keyboard shortcut manager
- [ ] Screenshot versioning
- [ ] API & AppleScript support
### 🌟 Version 4.0+ (Long-term Vision)
- [ ] iOS companion app
- [ ] Team collaboration features
- [ ] Video recording integration
- [ ] GIF creation from captures
- [ ] Screenshot scheduling
- [ ] Browser extension integration
- [ ] Screenshot templates with device frames
- [ ] Backup & sync options
- [ ] Screenshot analytics dashboard
- [ ] Custom watermarking

### 🤖 Version 5.0 - AI-Powered Features (Future Vision)

#### 21. AI OCR Everywhere
Instantly extract text from any screenshot:
- 📋 **Copy to Clipboard** - Extract and copy text instantly
- 💾 **Save as TXT** - Export recognized text to file
- 🔍 **Searchable Index** - Full-text search across all screenshots
- 🔦 **Spotlight Integration** - Find screenshots by contained text

**Example Use Cases:**
- Extract code from tutorial screenshots
- Copy text from error messages
- Search for specific content in screenshots
- Index all text for quick retrieval

#### 22. AI Smart Naming
AI analyzes screenshot content and suggests intelligent filenames:

**Before:**
```
Screenshot_2025-02-20_19-32-12.png
Screenshot_2025-02-20_19-33-45.png
Screenshot_2025-02-20_19-35-21.png
```

**After:**
```
Xcode Build Error Log.png
Safari_Apple Event Article.png
Slack Message from John.png
VSCode Python Function.png
```

**Features:**
- 🧠 Context detection from visible text
- 📱 App name recognition (Safari, Xcode, Slack, etc.)
- 📝 Content type identification (error, article, message, code)
- 🎯 Smart suggestions with confidence scores
- ✏️ One-click accept or manual override

#### 23. AI Redaction
Automatically detect and redact sensitive information:

**Auto-Detect:**
- 📧 Email addresses
- 👤 Faces and profile pictures
- 🏠 Physical addresses
- 🔒 Passwords and tokens
- 🔑 API keys and secrets
- 📁 File paths and system info
- 🌐 IP addresses and URLs
- 💳 Credit card numbers
- 📞 Phone numbers

**Privacy Modes:**
- **Smart Blur** - Gaussian blur over sensitive areas
- **Pixelate** - Pixelation effect
- **Black Box** - Solid black rectangles
- **Custom Color** - User-defined color overlay

**Workflow:**
1. Capture screenshot
2. AI scans for sensitive data (instant)
3. Preview with highlighted detections
4. One-click to redact all or selective redaction
5. Save redacted version

**Use Cases:**
- Share error logs without exposing credentials
- Post tutorial screenshots safely
- Bug reports with privacy protection
- Public documentation from internal tools

#### 24. AI Summaries (Super Useful!)
Transform screenshots into actionable content:

**Summary Types:**
- 📝 **Quick Summary** - 2-3 sentence overview
- ✅ **Action Items** - Extracted tasks and todos
- 🐛 **Bug Report** - Formatted issue description
- 📖 **Documentation** - Tutorial-style explanation
- 💡 **Key Points** - Bullet-point highlights

**Example Workflows:**

**Error Screenshot:**
```
Input: Screenshot of Xcode error
AI Summary: "The error indicates missing Info.plist key for 
NSCameraUsageDescription. Add camera permission description 
to resolve."

Action Items:
• Open Info.plist
• Add NSCameraUsageDescription key
• Provide user-facing description
```

**Meeting Notes Screenshot:**
```
Input: Screenshot of Slack discussion
AI Summary: "Team discussed new feature requirements. John 
suggested API-first approach. Sarah will provide designs by Friday."

Action Items:
• John: Draft API specification by Wed
• Sarah: Deliver UI designs by Fri
• Team: Review meeting next Monday
```

**Code Review Screenshot:**
```
Input: Screenshot of code with comments
Bug Report Format:
---
Title: Memory leak in image processing
Description: ImageCache retains references after deallocation
Steps to Reproduce: [extracted from screenshot]
Expected: Immediate release
Actual: Retained until app restart
---
```

**Voice Commands:**
- "Summarize last screenshot"
- "Extract action items"
- "Create bug report from screenshot"
- "Generate documentation from this capture"

#### 25. AI Compare Screenshots
Intelligent visual comparison for design and development:

**Comparison Modes:**
- 🎨 **UI Differences** - Highlight layout and style changes
- 🔍 **Pixel-Perfect** - Detect any pixel-level changes
- 📊 **Side-by-Side** - Before/after comparison view
- 🎭 **Overlay** - Translucent overlay showing differences
- 🎬 **Animation** - Smooth transition between versions

**Features:**
- **Difference Heatmap** - Color-coded change intensity
- **Change Percentage** - Quantify how much changed
- **Element Detection** - Identify moved/added/removed elements
- **Smart Alignment** - Auto-align similar screenshots
- **Export Comparison** - Save annotated comparison image

**Use Cases:**
- **UI/UX Design:** Track design iterations
- **Code Changes:** Visual diff of rendered output
- **Bug Tracking:** Show before/after fix
- **A/B Testing:** Compare design variants
- **Regression Testing:** Detect unintended changes

**Workflow Example:**
```
1. Select two screenshots to compare
2. AI analyzes and aligns images
3. View highlighted differences
4. Export comparison with annotations
5. Share with team or add to documentation
```

**Advanced Features:**
- **Smart Ignore Zones** - Exclude timestamps, dynamic content
- **Semantic Comparison** - Understand functional vs. visual changes
- **Timeline View** - Compare multiple versions chronologically
- **Auto-Regression Detection** - Flag unexpected UI changes

---

### 🎯 AI Feature Implementation Roadmap

**Phase 1: Foundation (v5.0)**
1. ✅ OCR Integration (Vision framework)
2. ✅ Basic text extraction
3. ✅ Searchable index

**Phase 2: Intelligence (v5.5)**
1. Smart naming with ML
2. Content categorization
3. Sensitive data detection

**Phase 3: Advanced AI (v6.0)**
1. Natural language summaries
2. Action item extraction
3. Bug report generation

**Phase 4: Visual Intelligence (v6.5)**
1. Screenshot comparison
2. UI diff detection
3. Regression testing

---

### 💡 AI Features Note

These AI-powered features will leverage:
- 🧠 **Apple Vision Framework** - On-device OCR and text recognition
- 🤖 **Core ML** - Local machine learning models
- 🔒 **Privacy First** - All processing happens on-device
- ⚡ **Apple Neural Engine** - Hardware-accelerated AI
- 📱 **Apple Intelligence** - Integration with system AI features

**No cloud processing required - your data stays on your Mac!**


### 💡 Community Feature Voting

Want to influence our roadmap? 
- 🗳️ [Vote on features](https://github.com/yourusername/ScreenGrabber/discussions/categories/feature-requests)
- 💬 [Join discussions](https://github.com/yourusername/ScreenGrabber/discussions)
- 🐛 [Report bugs](https://github.com/yourusername/ScreenGrabber/issues)
- 🤝 [Contribute code](https://github.com/yourusername/ScreenGrabber/pulls)

---

## 📈 Recent Updates

**Version 2.0 - Enhanced Edition** (November 2025)
- ✨ Added 8 major new features
- 🎨 Redesigned settings interface
- ⚡ Performance improvements
- 📚 Comprehensive documentation
- 🐛 Bug fixes and stability improvements

---

## 📊 Stats

![GitHub stars](https://img.shields.io/github/stars/yourusername/ScreenGrabber)
![GitHub forks](https://img.shields.io/github/forks/yourusername/ScreenGrabber)
![GitHub issues](https://img.shields.io/github/issues/yourusername/ScreenGrabber)
![GitHub pull requests](https://img.shields.io/github/issues-pr/yourusername/ScreenGrabber)

---

<div align="center">

**Made with ❤️ for macOS**

[⬆ Back to Top](#screengrabber)

</div>
