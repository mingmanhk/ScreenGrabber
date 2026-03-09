//
//  QUICK_REFERENCE.md
//  ScreenGrabber
//
//  Quick reference for screenshot capture system
//

# ScreenGrabber - Quick Reference

## 🎯 What Was Fixed

| Issue | Status | Solution |
|-------|--------|----------|
| Screenshots not saving | ✅ FIXED | Integrated CaptureFileStore.saveImage() |
| Recent Captures empty | ✅ FIXED | Added notification posting + reload |
| Clipboard toggle broken | ✅ FIXED | Bound to SettingsModel.shared |
| Settings not persisting | ✅ FIXED | Removed local @State, use @ObservedObject |
| UI not updating | ✅ FIXED | Dual notification system |

## 📁 Files Changed

```
Modified:
├── ManagersScreenCaptureManager.swift  (saveCapture refactored)
├── CapturePanel.swift                  (settings binding fixed)
├── CaptureHistoryStore.swift           (notification added)
└── MenuBarContentView.swift            (reload enhanced)

Created:
├── NotificationNames.swift             (centralized notifications)
├── CAPTURE_FLOW_FIXES.md               (detailed documentation)
├── TESTING_GUIDE.md                    (test procedures)
└── IMPLEMENTATION_SUMMARY.md           (this summary)
```

## 🔄 Data Flow

```
User clicks "Capture"
    ↓
ScreenCaptureManager.captureScreen()
    ↓
Capture image (area/window/screen)
    ↓
ScreenCaptureManager.saveCapture()
    ├─→ CaptureFileStore.saveImage()     [Saves PNG to disk]
    └─→ CaptureHistoryStore.addCapture() [Saves to database]
        └─→ Post .screenshotSavedToHistory
    ↓
Copy to clipboard (if enabled)
    ↓
Post .screenshotCaptured
    ↓
MenuBarContentView receives notification
    ↓
loadRecentScreenshots()
    ↓
UI updates with new screenshot ✅
```

## ⚙️ Settings Architecture

```swift
// ❌ OLD WAY (Don't do this)
struct CapturePanel: View {
    @State private var copyToClipboard = true  // Local state
}

// ✅ NEW WAY (Do this)
struct CapturePanel: View {
    @ObservedObject var settingsModel = SettingsModel.shared
    
    var body: some View {
        Toggle("Copy to Clipboard", isOn: $settingsModel.copyToClipboardEnabled)
    }
}
```

## 📋 Key Properties

| Setting | Property | Type | Default |
|---------|----------|------|---------|
| Copy to Clipboard | `copyToClipboardEnabled` | Bool | false |
| Preview in Editor | `previewInEditorEnabled` | Bool | false |
| Time Delay | `timeDelayEnabled` | Bool | false |
| Delay Duration | `timeDelaySeconds` | Double | 3.0 |
| Include Cursor | `includeCursor` | Bool | false |
| Save Location | `effectiveSaveURL` | URL | ~/Pictures/Screen Grabber |

## 🔔 Notifications

```swift
// Posted after capture completes
.screenshotCaptured
    object: Screenshot
    userInfo: ["url": URL]

// Posted after database save
.screenshotSavedToHistory
    object: Screenshot
    userInfo: ["url": URL]

// Posted after OCR completes
.screenshotOCRCompleted
    userInfo: ["url": URL, "text": String]
```

## 🧪 Quick Test

```bash
# 1. Take a screenshot
# 2. Check console for:
[CAPTURE] ✅ Saved to: /path/to/file.png
[CAPTURE] ✅ Added to history database
[MENU] ✅ Loaded 1 screenshots from database

# 3. Verify file exists:
ls -lh ~/Pictures/Screen\ Grabber/

# 4. Check Recent Captures UI
# Should show thumbnail and count badge
```

## 🐛 Troubleshooting

| Symptom | Check | Fix |
|---------|-------|-----|
| File not saving | Console logs | Check save path permissions |
| UI not updating | Notifications | Verify ModelContext passed |
| Clipboard not working | Toggle state | Enable in CapturePanel |
| Settings not persisting | UserDefaults | Check @AppStorage bindings |

## 📊 Console Log Key

```
🎬 Capture started
📐 Area selection
🪟 Window selection
💾 Saving file
✅ Success
❌ Error
⚠️ Warning
ℹ️ Info
📋 Clipboard operation
🔄 Reload operation
📊 Statistics
```

## 🎯 Testing Checklist

- [ ] Screenshot saves to folder
- [ ] Recent Captures updates
- [ ] Clipboard copies (when enabled)
- [ ] Settings persist after restart
- [ ] Multiple captures work
- [ ] Error alerts show (invalid path)

## 📚 Documentation

- **CAPTURE_FLOW_FIXES.md** - Detailed technical documentation
- **TESTING_GUIDE.md** - Step-by-step test procedures
- **IMPLEMENTATION_SUMMARY.md** - Complete change summary

## 🚀 Usage

### Capture a Screenshot:
```swift
await ScreenCaptureManager.shared.captureScreen(
    method: .selectedArea,
    openOption: .saveToFile,
    modelContext: modelContext
)
```

### Load Recent Captures:
```swift
await CaptureHistoryStore.shared.loadRecentCaptures(
    from: modelContext,
    limit: 20
)
```

### Save Image:
```swift
let result = await CaptureFileStore.shared.saveImage(
    image,
    type: .area,
    timestamp: Date()
)
```

### Copy to Clipboard:
```swift
let result = await CaptureClipboardService.shared.copyToClipboard(image)
```

## 🔑 Key Classes

| Class | Purpose | Location |
|-------|---------|----------|
| `ScreenCaptureManager` | Main capture coordinator | ManagersScreenCaptureManager.swift |
| `CaptureFileStore` | File save operations | CaptureFileStore.swift |
| `CaptureHistoryStore` | Database management | CaptureHistoryStore.swift |
| `CaptureClipboardService` | Clipboard operations | CaptureClipboardService.swift |
| `SettingsModel` | Settings persistence | SettingsModel.swift |

## 💡 Best Practices

1. **Always use Result types** for async operations
2. **Log extensively** with emoji categories
3. **Handle errors gracefully** with user-friendly alerts
4. **Post notifications** after state changes
5. **Bind to SettingsModel** for persistent settings
6. **Pass ModelContext** through call chain
7. **Use @MainActor** for UI updates

## 📞 Support

**Console Logs:** Essential for debugging
**Error Alerts:** User-friendly recovery options
**Documentation:** See markdown files in /repo

---

**Last Updated:** January 25, 2026
**Status:** ✅ Production Ready
