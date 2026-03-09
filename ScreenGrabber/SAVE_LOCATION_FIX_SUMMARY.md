# Save Location Persistence Fix

## Problem
The app was not persisting the user's selected screenshot save location. Every time the app reopened, it would ask the user to select the location again.

## Root Causes

### 1. UserDefaults Key Mismatch
- `FolderPermissionsManager` was saving to: `"customScreenshotLocation"`
- `SettingsModel` was reading from: `"customSaveLocation"` 
- These two keys never synced, so the settings model never knew about the user's choice

### 2. Missing Security-Scoped Bookmarks
- The app was only saving the file path as a string
- On macOS, apps need **security-scoped bookmarks** to maintain persistent access to user-selected folders
- Without bookmarks, the app loses access to custom folders when it relaunches

## Solutions Implemented

### 1. Fixed UserDefaults Key (SettingsModel.swift)
```swift
// Changed from:
@AppStorage("customSaveLocation") var customSaveLocationPath: String?

// To:
@AppStorage("customScreenshotLocation") var customSaveLocationPath: String?
```

### 2. Added Security-Scoped Bookmarks (FolderPermissionsManager.swift)

#### New Methods:
- `saveBookmark(for:)` - Creates and saves a security-scoped bookmark when user selects a folder
- `restoreBookmarkedURL()` - Restores the URL from the bookmark and starts accessing the security-scoped resource
- Properly tracks `currentSecurityScopedURL` and cleans up in `deinit`

#### Updated Flow:
1. When user selects a custom folder, app now:
   - Saves the path string (as before)
   - **NEW:** Creates and saves a security-scoped bookmark
   
2. When app launches and needs the save location:
   - **NEW:** First tries to restore from bookmark
   - Falls back to path-based lookup if bookmark fails
   - Falls back to default `~/Pictures/Screen Grabber` if no custom location

3. Security-scoped resource management:
   - Starts accessing the resource when restored
   - Tracks the current URL
   - Stops accessing in `deinit` to clean up properly

## Technical Details

### Security-Scoped Bookmarks
Security-scoped bookmarks are required on macOS for:
- Sandboxed apps
- Apps that need persistent access to user-selected files/folders
- Maintaining access across app launches

The bookmark stores:
- The folder location
- Permission information
- Validity state (stale detection)

### Implementation
```swift
// Creating a bookmark
let bookmarkData = try url.bookmarkData(
    options: .withSecurityScope,
    includingResourceValuesForKeys: nil,
    relativeTo: nil
)
UserDefaults.standard.set(bookmarkData, forKey: "customScreenshotLocationBookmark")

// Restoring from bookmark
let url = try URL(
    resolvingBookmarkData: bookmarkData,
    options: .withSecurityScope,
    relativeTo: nil,
    bookmarkDataIsStale: &isStale
)
guard url.startAccessingSecurityScopedResource() else { return nil }

// Remember to stop accessing when done
url.stopAccessingSecurityScopedResource()
```

## Testing Checklist

- [x] Fixed warning in UtilitiesCaptureLogger.swift (removed unnecessary `nonisolated(unsafe)` from NSLock)
- [x] Standardized UserDefaults key across the app
- [x] Implemented security-scoped bookmarks
- [ ] Test: Select custom save location → Close app → Reopen → Verify location persists
- [ ] Test: Use default location → Close app → Reopen → Verify default still works
- [ ] Test: Select invalid location → Verify app falls back gracefully
- [ ] Test: Verify screenshots actually save to the selected location

## Additional Notes

### Entitlements
If the app is sandboxed, ensure these entitlements are set in Xcode:
- `com.apple.security.files.user-selected.read-write` - Required for user-selected folder access
- `com.apple.security.files.bookmarks.app-scope` - Required for security-scoped bookmarks

### Migration
Users who selected a custom location before this fix will need to:
1. Reselect their custom location once (the old path-only method is kept as fallback)
2. After reselection, the bookmark will be created and persist properly

### Logging
All folder operations now log with `[PERMISSIONS]` prefix for easy debugging:
- ✅ Success operations
- ⚠️ Warnings and fallbacks
- ❌ Errors
