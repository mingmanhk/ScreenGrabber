# 🏗️ ScreenGrabber Architecture — Fixed Flow Diagrams

## 1. SAVE LOCATION RESOLUTION FLOW

```
┌─────────────────────────────────────────────────────────────────┐
│                     USER TRIGGERS CAPTURE                        │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│              SettingsModel.effectiveSaveURL                      │
├─────────────────────────────────────────────────────────────────┤
│  1. Check if saveFolderPath is not empty                        │
│  2. Convert to URL using URL(fileURLWithPath:) ✅               │
│  3. Validate folder exists                                      │
│  4. Test write permissions                                      │
└─────────┬───────────────────────────────┬───────────────────────┘
          │                               │
          │ ✅ Valid                      │ ❌ Invalid
          │                               │
          ▼                               ▼
┌──────────────────────┐    ┌──────────────────────────────────┐
│  Return Custom URL   │    │  Clear saveFolderPath            │
└──────────────────────┘    │  Show Error Alert to User        │
                            │  Fall Back to Default            │
                            └────────┬─────────────────────────┘
                                     │
                                     ▼
                     ┌────────────────────────────────────┐
                     │  Return Default:                   │
                     │  ~/Pictures/Screen Grabber/        │
                     └────────────────────────────────────┘
```

### Key Points:
- ✅ **No silent failures** — User is always notified
- ✅ **Validation at every step** — Existence + Write access
- ✅ **Graceful fallback** — Default location always works
- ✅ **Logging** — Every decision is logged

---

## 2. SETTINGS WINDOW ACCESS FLOW

```
┌──────────────────────────────────────────────────────────────┐
│                  USER WANTS TO OPEN SETTINGS                  │
└────┬─────────────────────┬──────────────────┬────────────────┘
     │                     │                  │
     │ Menu Bar           │ Keyboard         │ MenuBar Extra
     │                     │                  │
     ▼                     ▼                  ▼
┌─────────────┐  ┌─────────────────┐  ┌──────────────────┐
│ ScreenGrab  │  │   Press ⌘,      │  │  Click Gear Icon │
│ → Settings  │  │                 │  │                  │
└──────┬──────┘  └────────┬────────┘  └────────┬─────────┘
       │                  │                    │
       │ ✅ CommandGroup  │ ✅ Shortcut        │ ✅ openWindow
       │                  │                    │
       └──────────────────┴────────────────────┘
                          │
                          ▼
       ┌──────────────────────────────────────────┐
       │  Window("settings") Opens                │
       │  - Single instance (not WindowGroup)     │
       │  - NavigationSplitView with sections:    │
       │    • General                             │
       │    • Capture (Save Location)             │
       │    • Video & Audio                       │
       └──────────────────────────────────────────┘
```

### Key Points:
- ✅ **Three access methods** — Menu, Keyboard, Button
- ✅ **Single window** — Using `Window` not `WindowGroup`
- ✅ **macOS standard** — ⌘, keyboard shortcut
- ✅ **HIG compliant** — "Settings..." menu item

---

## 3. SCROLLING CAPTURE — FIXED FLOW

### BEFORE (BROKEN):
```
User Clicks "Scrolling" → AutoScrollCaptureWindow Opens
                                  │
                                  ▼
                          Shows Instruction
                                  │
                                  ▼
                          ❌ Grey overlay appears
                          ❌ Blocks all interaction
                          ❌ No window picker shown
                          ❌ User stuck in modal
```

### AFTER (FIXED):
```
┌─────────────────────────────────────────────────────────────────┐
│  User Clicks "Scrolling" in Menu Bar                            │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  AutoScrollCaptureWindow Opens                                  │
│  - Shows instructions                                            │
│  - Settings (scroll distance, delay, max frames)                │
│  - "Start Automatic Capture" button                             │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      │ User clicks Start
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  startCapture() → WindowPickerOverlay.show()                    │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  WindowPickerOverlay Appears                                    │
├─────────────────────────────────────────────────────────────────┤
│  ✅ Semi-transparent grey background (30% opacity)              │
│  ✅ Window level: .floating (allows interaction)                │
│  ✅ ignoresMouseEvents: false                                   │
│  ✅ All windows highlighted with blue borders                   │
│  ✅ Hover effect shows window title                             │
│  ✅ Click on window → handleWindowSelection()                   │
│  ✅ Click outside → dismiss()                                   │
│  ✅ Press Escape → dismiss()                                    │
│  ✅ Cancel button → dismiss()                                   │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      │ Window selected
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  performScrollCapture(window: SelectableWindow)                 │
├─────────────────────────────────────────────────────────────────┤
│  1. Get window reference from ScreenCaptureKit                  │
│  2. For each scroll step:                                       │
│     - Capture frame                                             │
│     - Scroll window                                             │
│     - Wait for scrollDelay                                      │
│     - Update UI progress                                        │
│  3. Stitch frames together                                      │
│  4. Save final image                                            │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│  state = .completed                                             │
│  Show "Save & Finish" button                                    │
│  Preview frames in UI                                           │
└─────────────────────────────────────────────────────────────────┘
```

### Key Fixes:
- ✅ **WindowPickerOverlay integrated** — Not just a placeholder
- ✅ **Non-blocking overlay** — `.floating` level, not `.screenSaver`
- ✅ **Interactive highlights** — Each window has `.onTapGesture`
- ✅ **Multiple dismiss methods** — Cancel, Escape, Click outside
- ✅ **Clear instructions** — Banner with visual icon
- ✅ **State management** — Proper state transitions

---

## 4. ERROR HANDLING HIERARCHY

```
┌──────────────────────────────────────────────────────────────────┐
│                    CAPTURE OPERATION                             │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────────┐
        │  Validate Environment              │
        │  - Permissions                     │
        │  - Save folder                     │
        └────┬────────────────────┬──────────┘
             │ ✅                 │ ❌
             │                    │
             ▼                    ▼
    ┌─────────────┐     ┌──────────────────────┐
    │   Capture   │     │  CaptureError        │
    └──────┬──────┘     │  - permissionDenied  │
           │            │  - folderCreation    │
           │ ✅ / ❌    │  - fileWrite         │
           │            └──────────┬───────────┘
           ▼                       │
    ┌─────────────┐                │
    │    Save     │                │
    └──────┬──────┘                │
           │ ✅ / ❌               │
           │                       │
           ▼                       │
    ┌─────────────┐                │
    │   Success   │                │
    └─────────────┘                │
                                   ▼
                    ┌───────────────────────────────┐
                    │  Error Handler                │
                    ├───────────────────────────────┤
                    │  1. Log error with context    │
                    │  2. Show user-friendly alert  │
                    │  3. Offer recovery options:   │
                    │     - Open System Settings    │
                    │     - Choose different folder │
                    │     - Retry                   │
                    │     - Use fallback            │
                    └───────────────────────────────┘
```

### Recovery Actions by Error Type:

| Error Type | Recovery Options |
|------------|------------------|
| **Permission Denied** | • Open System Settings → Privacy & Security<br>• Show instructions<br>• Retry after user grants |
| **Folder Missing** | • Choose new folder<br>• Reset to default<br>• Create folder automatically |
| **Disk Full** | • Show storage usage<br>• Offer to compress existing captures<br>• Save to different location |
| **Unknown** | • Retry with backoff<br>• Export logs<br>• Report bug |

---

## 5. SETTINGS VALIDATION FLOW

```
┌──────────────────────────────────────────────────────────────┐
│  User Opens Settings → Capture Tab                           │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────────┐
│  SaveFolderStatusView                                        │
│  - Calls CapturePermissionsManager.ensureCaptureFolderExists│
└────────┬─────────────────────────┬───────────────────────────┘
         │ ✅ Success              │ ❌ Failure
         │                         │
         ▼                         ▼
┌─────────────────────┐   ┌─────────────────────────────┐
│ ✅ Green Checkmark  │   │ ⚠️ Orange Warning           │
│    "Ready"          │   │    "Check permissions"      │
└─────────────────────┘   └─────────────┬───────────────┘
                                        │
                     User clicks "Choose Different Folder"
                                        │
                                        ▼
                          ┌──────────────────────────┐
                          │  NSOpenPanel             │
                          │  - canChooseFiles: false │
                          │  - canChooseDirectories  │
                          │  - canCreateDirectories  │
                          └─────────┬────────────────┘
                                    │
                                    │ User selects folder
                                    ▼
                    ┌────────────────────────────────┐
                    │  Validate Selection:           │
                    │  1. Check folder exists        │
                    │  2. Try to create if needed    │
                    │  3. Test write access          │
                    └────┬───────────────┬───────────┘
                         │ ✅            │ ❌
                         │               │
                         ▼               ▼
            ┌─────────────────┐  ┌──────────────────────┐
            │ Save to         │  │ Show Error Alert:    │
            │ saveFolderPath  │  │ "Cannot Use Selected │
            │                 │  │  Folder"             │
            │ Update UI ✅    │  │ + Recovery Options   │
            └─────────────────┘  └──────────────────────┘
```

---

## 6. COMPONENT INTERACTION MAP

```
┌──────────────────────────────────────────────────────────────────┐
│                     ScreenGrabberApp                             │
│  - Defines scenes                                                │
│  - Registers commands                                            │
│  - Manages model container                                       │
└────┬────────────────────┬────────────────────┬──────────────────┘
     │                    │                    │
     ▼                    ▼                    ▼
┌─────────────┐  ┌──────────────────┐  ┌─────────────────────┐
│ WindowGroup │  │ Window(settings) │  │ MenuBarExtra        │
│ (Library)   │  │                  │  │                     │
└─────────────┘  └────────┬─────────┘  └──────┬──────────────┘
                          │                   │
                          ▼                   ▼
                ┌───────────────────┐  ┌───────────────────────┐
                │ SettingsWindow    │  │ MenuBarContentView    │
                │ - General         │  │ - Quick capture       │
                │ - Capture ✅      │  │ - Recent screenshots  │
                │ - Video & Audio   │  │ - Settings button ✅  │
                └────────┬──────────┘  └──────┬────────────────┘
                         │                    │
                         ▼                    ▼
                ┌────────────────────┐  ┌─────────────────────┐
                │ CaptureSettingsPane│  │ ScreenCaptureManager│
                │ - Save location ✅ │  │ - Trigger captures  │
                │ - Validation ✅    │  │ - Handle results    │
                └────────┬───────────┘  └──────┬──────────────┘
                         │                     │
                         │                     ▼
                         │           ┌──────────────────────────┐
                         │           │ UnifiedCaptureManager    │
                         │           │ - getCapturesFolderURL() │
                         │           │ - Save screenshots       │
                         │           └────────┬─────────────────┘
                         │                    │
                         ▼                    ▼
                ┌──────────────────────────────────────────────┐
                │         SettingsModel.shared                 │
                │  - saveFolderPath (AppStorage)               │
                │  - effectiveSaveURL (computed) ✅            │
                │  - Validation logic ✅                       │
                └────────────────┬─────────────────────────────┘
                                 │
                                 ▼
                ┌──────────────────────────────────────────────┐
                │    CapturePermissionsManager.shared          │
                │  - ensureCaptureFolderExists()               │
                │  - checkAndRequestPermissions()              │
                │  - validateCaptureEnvironment()              │
                └──────────────────────────────────────────────┘
```

### Data Flow:
1. **Settings Change**: User changes folder → `saveFolderPath` updated
2. **Validation**: `effectiveSaveURL` validates on access
3. **Capture**: Manager uses `effectiveSaveURL` for saving
4. **Permissions**: Manager ensures folder exists before capture

---

## 7. THREAD SAFETY & CONCURRENCY

```
┌──────────────────────────────────────────────────────────────┐
│                      @MainActor                              │
│  - UI Updates                                                │
│  - Window Management                                         │
│  - Settings Changes                                          │
│  - Alert Display                                             │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ Task { }
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                   Background Actor/Task                      │
│  - File I/O                                                  │
│  - Image Processing                                          │
│  - Network Requests                                          │
│  - Heavy Computation                                         │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         │ await MainActor.run { }
                         ▼
┌──────────────────────────────────────────────────────────────┐
│                    @MainActor                                │
│  - Update UI with results                                    │
│  - Show success/error alerts                                 │
│  - Refresh views                                             │
└──────────────────────────────────────────────────────────────┘
```

### Example Pattern:
```swift
func captureScreen() {
    Task {
        // Background: Heavy work
        let image = await performCapture()
        let savedURL = await saveImage(image)
        
        // Main actor: UI update
        await MainActor.run {
            showSuccessNotification(url: savedURL)
            refreshRecentScreenshots()
        }
    }
}
```

---

**These diagrams show the complete fixed architecture with all interaction flows properly connected.** ✅
