# ✅ Quick Fix Checklist

## Automatic Fixes Applied ✅

- [x] Added `import Combine` to `CaptureHistoryStore.swift`
- [x] Added `import Combine` to `EditorWindowHelper.swift`
- [x] Created `CaptureError.swift` with all error types
- [x] Created `EditorModels.swift` with centralized `EditorTool` enum
- [x] Renamed `EditorToolButton` → `EditorPanelToolButton` in `EditorPanel.swift`
- [x] Removed duplicate `EditorTool` definition from `EditorPanel.swift`

## Manual Steps Required ⚠️

### 1. Verify Target Membership (2 minutes)

#### Annotation.swift + CodableGeometry.swift
- [ ] Select `Annotation.swift` in Project Navigator
- [ ] Open File Inspector (⌥⌘1)
- [ ] Check "ScreenGrabber" target is selected
- [ ] Select `CodableGeometry.swift`
- [ ] Check "ScreenGrabber" target is selected

#### New Files
- [ ] Select `CaptureError.swift` in Project Navigator
- [ ] Verify "ScreenGrabber" target is selected
- [ ] Select `EditorModels.swift`
- [ ] Verify "ScreenGrabber" target is selected

### 2. Fix UnifiedCaptureManager (1 minute)

Choose ONE option:

#### Option A: Find and Replace (Recommended)
- [ ] Press ⌘⇧F (Find in Project)
- [ ] Search: `UnifiedCaptureManager` (not in UnifiedCaptureManager.swift)
- [ ] Replace with: `LegacyUnifiedCaptureManager`

#### Option B: Add Alias
- [ ] Open `UnifiedCaptureManager.swift`
- [ ] Add after imports:
```swift
typealias UnifiedCaptureManager = LegacyUnifiedCaptureManager
```

#### Option C: Find Version 2
- [ ] Press ⌘⇧O
- [ ] Type: `UnifiedCaptureManager 2`
- [ ] If found, verify it's in the build target

### 3. Clean and Rebuild (30 seconds)

- [ ] Product → Clean Build Folder (⇧⌘K)
- [ ] Product → Build (⌘B)
- [ ] View → Navigators → Issue Navigator (⌘5)
- [ ] Verify 0 errors (1 intentional warning is OK)

## 🎯 Success Criteria

After completing all steps:
- ✅ 0 build errors
- ✅ Project builds successfully
- ✅ 1 warning (ScrollCaptureView - intentional)

## 📝 Notes

- The `ScrollCaptureView` warning is intentional for backward compatibility
- All other warnings in the FINAL_FIX_INSTRUCTIONS.md are cosmetic (deprecated APIs)
- You can fix those warnings later without affecting build success

## ⏱️ Total Time: ~3 minutes

1. Target membership checks: 2 minutes
2. UnifiedCaptureManager fix: 1 minute
3. Clean and rebuild: 30 seconds

---

**Ready to build!** 🚀
