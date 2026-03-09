# Fix Instructions for ScreenGrabber Build Errors

## Summary
Your project has duplicate type declarations causing ambiguous type lookup errors. These duplicates need to be removed from the project.

## Files to DELETE from Your Project

Delete these files completely (Move to Trash in Xcode):

### 1. **Screenshot.swift** (NOT ModelsScreenshot.swift)
- **Location**: `/Users/victor/Documents/Xcode/ScreenGrabber/ScreenGrabber/Screenshot.swift`
- **Reason**: This file is a simpler/older version. `ModelsScreenshot.swift` is the production-ready version and should be kept.
- **Conflicts**: Declares both `Screenshot` and `Annotation` classes that conflict with `ModelsScreenshot.swift` and `ModelsAnnotation.swift`

### 2. **SettingsManager 2.swift**
- **Location**: `/Users/victor/Documents/Xcode/ScreenGrabber/ScreenGrabber/SettingsManager 2.swift`
- **Reason**: Duplicate of `SettingsManager.swift`. The " 2" suffix indicates an accidental duplicate.
- **Note**: I've already updated the header comment, but the file still needs to be deleted or properly renamed and used.

### 3. **ScreenGrabberTypes 2.swift**
- **Location**: `/Users/victor/Documents/Xcode/ScreenGrabber/ScreenGrabber/ScreenGrabberTypes 2.swift`
- **Reason**: Duplicate of `ScreenGrabberTypes.swift`
- **Conflicts**: Both files declare `enum ScreenGrabberTypes`, causing ambiguous lookup

### 4. **CapturePermissionsManager 2.swift**
- **Location**: `/Users/victor/Documents/Xcode/ScreenGrabber/ScreenGrabber/CapturePermissionsManager 2.swift`
- **Reason**: Duplicate of `CapturePermissionsManager.swift`
- **Conflicts**: Declares `CapturePermissionsManager` and `FolderPermissionsManager` classes

## Files Already Fixed

### ✅ **SupportingTypes.swift**
- **Fixed**: Removed duplicate `EditorTool` enum declaration
- **Action**: Keep this file, changes already applied
- **Note**: Now uses the centralized `EditorTool` from `EditorModels.swift`

## Additional Errors to Fix

### Issue: Missing CaptureLogger.Category.clipboard
**Files Affected**: 
- `CaptureClipboardService.swift` (if it exists)

**Solution**: Add `.clipboard` case to `CaptureLogger.Category` enum, or change the logger calls to use an existing category like `.general` or `.capture`

### Issue: Invalid redeclaration of 'getOCRText(for:)'
**File**: `ScreenCaptureEditor.swift:14`

**Current Code**:
```swift
extension ScreenCaptureManager {
    func getOCRText(for url: URL) -> String? { return nil }
    ...
}
```

**Problem**: This function is likely declared elsewhere (maybe in ScreenCaptureManager itself or another extension)

**Solution**: Remove or rename this duplicate declaration

## How to Delete Files in Xcode

1. Open your project in Xcode
2. In the **Project Navigator** (left sidebar - Cmd+1), locate each file listed above
3. **Right-click** on the file
4. Select **"Delete"**
5. In the dialog that appears, choose **"Move to Trash"** (this removes it from both the project and file system)
6. Repeat for all files listed above

## Verification

After deleting these files, clean and rebuild:

1. **Product** → **Clean Build Folder** (Cmd+Shift+K)
2. **Product** → **Build** (Cmd+B)

All ambiguous type lookup errors should be resolved.

## Files to KEEP (Production-Ready Versions)

- ✅ `ModelsScreenshot.swift` - Keep (production-ready Screenshot model)
- ✅ `ModelsAnnotation.swift` - Keep (production-ready Annotation model)
- ✅ `EditorModels.swift` - Keep (centralized EditorTool enum)
- ✅ `ScreenGrabberTypes.swift` - Keep (original, not " 2" version)
- ✅ `CapturePermissionsManager.swift` - Keep (original, not " 2" version)
- ✅ `SettingsManager.swift` - Keep (original, not " 2" version)
- ✅ `SupportingTypes.swift` - Keep (duplicate EditorTool removed)

## Summary of What Happened

The " 2" files were likely created when:
- Files were duplicated in Finder or Xcode
- You attempted to refactor but didn't remove old versions
- Files were copied/pasted within the project

The Swift compiler saw multiple declarations of the same types and couldn't determine which one to use, causing "ambiguous" errors throughout your project.
