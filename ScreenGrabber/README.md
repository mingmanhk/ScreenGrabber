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

## 🗺️ Roadmap

### Version 2.0 (Coming Soon)
- [ ] Cloud sync support
- [ ] Advanced image editing
- [ ] Screenshot annotations
- [ ] OCR text extraction
- [ ] Quick Share extensions
- [ ] Keyboard shortcut manager

### Future Plans
- [ ] iOS companion app
- [ ] Team collaboration features
- [ ] Video recording
- [ ] GIF creation
- [ ] Screenshot scheduling
- [ ] Browser extension integration

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