# ScreenGrabber App

A powerful macOS menu bar screenshot application with global hotkey support.

## Features

### ✅ **Automatic File Saving**
- **All screenshots are automatically saved** to `~/Pictures/ScreenGrabber/` folder
- The app creates the folder automatically if it doesn't exist
- Files are named with timestamps: `Screenshot_YYYY-MM-DD_HH-mm-ss.png`

### ✅ **Working Global Hotkeys**
- **Default hotkey:** `⌘⇧C` (Command + Shift + C)
- **Customizable hotkeys** through the app interface
- **Global system-wide functionality** - works from any app
- Triggers the currently selected screen capture method

### ✅ **Multiple Capture Methods**
1. **Selected Area** (`⌘⇧4`) - Click and drag to select area
2. **Window** (`⌘⇧4 + Space`) - Click on any window
3. **Full Screen** (`⌘⇧3`) - Captures entire screen
4. **Scrolling** (`⌘⇧S`) - Currently uses selected area (can be enhanced)

### ✅ **Flexible Output Options**
1. **Clipboard** - Copy screenshot to clipboard (+ save to file)
2. **Save to File** - Save only to ScreenGrabber folder
3. **Preview** - Open in Preview app (+ save to file)

### ✅ **Recent Screenshots**
- View up to 5 most recent captures in the menu
- Quick preview and share options
- Files are tracked automatically from the ScreenGrabber folder

## How It Works

### Global Hotkey System
1. The app uses `GlobalHotkeyManager` class with Carbon framework
2. Registers system-wide keyboard shortcuts
3. When hotkey is pressed, triggers screenshot with current settings
4. Settings are persisted between app launches

### Screenshot Capture Process
1. **All captures save to file first** in ScreenGrabber folder
2. Then handles additional options (clipboard, preview) as needed
3. Uses macOS built-in `screencapture` command for reliability
4. Tracks captures in SwiftData database for history

### Menu Bar Interface
1. **Screen options** - Select capture method (area, window, full screen, scrolling)
2. **Open options** - Choose what happens after capture
3. **Recent captures** - Quick access to recent screenshots
4. **Hotkey configuration** - Customize global shortcut
5. **Grab Screen button** - Manual capture trigger

## Installation & Setup

1. Build and run the app in Xcode
2. Grant necessary permissions:
   - **Accessibility permission** (for global hotkeys)
   - **Screen Recording permission** (for screenshots)
   - **Notifications permission** (for capture confirmations)
3. The app will appear in your menu bar
4. Click to open interface or use hotkey from anywhere

## Technical Implementation

### Key Components

1. **GlobalHotkeyManager** - Handles system-wide keyboard shortcuts using Carbon framework
2. **ScreenCaptureManager** - Manages all screenshot operations and file handling
3. **MenuBarContentView** - Main user interface in the popover
4. **Screenshot** SwiftData model - Tracks capture history
5. **AppDelegate** - Coordinates menu bar presence and global functionality

### File Structure
```
ScreenGrabber/
├── ScreenGrabberApp.swift          # App entry point & AppDelegate
├── MenuBarContentView.swift        # Main UI interface
├── GlobalHotkeyManager.swift       # Global hotkey system
├── ScreenCaptureManager.swift      # Screenshot handling
├── Screenshot.swift                # SwiftData model
├── Item.swift                     # Legacy model (can be removed)
└── ContentView.swift              # Hidden main window
```

## User Experience

### Setting Up Hotkeys
1. Click menu bar icon
2. Click "Set Hotkey" button
3. Choose from presets or enter custom combination
4. Hotkey works immediately across the entire system

### Taking Screenshots
#### Method 1: Global Hotkey
- Press your configured hotkey anywhere in macOS
- Screenshot is taken using current settings
- File automatically saved to ScreenGrabber folder

#### Method 2: Menu Interface
- Click menu bar icon
- Select capture method (area, window, full screen)
- Select output option (clipboard, file, preview)
- Click "Grab Screen" button

### Finding Your Screenshots
- All screenshots saved to: `~/Pictures/ScreenGrabber/`
- Recent captures shown in app interface
- Click eye icon to open in default image viewer
- Click share icon for system sharing options

## Customization

### Hotkey Options
- **Command combinations:** `⌘⇧C`, `⌘⇧G`, `⌘⇧S`, etc.
- **Custom hotkeys:** Use ⌘ (Command), ⇧ (Shift), ⌥ (Option), ⌃ (Control) + any letter
- Settings persist between app launches

### Capture Settings
- **Screen method** and **output option** preferences are saved
- **Global hotkey uses saved preferences** automatically
- Change settings anytime through menu interface

## Troubleshooting

### Hotkeys Not Working
1. Check **System Preferences > Security & Privacy > Privacy > Accessibility**
2. Ensure ScreenGrabber app is enabled
3. Restart the app if needed

### Screenshots Not Saving
1. Check **System Preferences > Security & Privacy > Privacy > Screen Recording**
2. Ensure ScreenGrabber app is enabled
3. Verify `~/Pictures/ScreenGrabber/` folder exists and is writable

### App Not Visible
- Look for the "G" icon in your menu bar (top-right area)
- If missing, restart the app
- Check Activity Monitor to ensure it's running

## Development Notes

This implementation provides a complete screenshot solution with:
- ✅ Global hotkey functionality that actually works
- ✅ All screenshots automatically saved to ScreenGrabber folder
- ✅ Persistent user preferences
- ✅ Menu bar interface for manual operation
- ✅ Recent captures tracking
- ✅ Multiple output options
- ✅ System permissions handling
- ✅ Native macOS integration

The hotkey system uses the Carbon framework for reliable system-wide keyboard monitoring, while the screenshot functionality leverages the built-in `screencapture` command for maximum compatibility and reliability.