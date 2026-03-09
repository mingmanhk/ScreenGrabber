//
//  TESTING_GUIDE.md
//  ScreenGrabber
//
//  Quick testing guide for verifying screenshot capture fixes
//

# Testing Guide for Screenshot Capture Fixes

## Quick Verification Steps

### Test 1: Basic Capture & Save
1. Launch ScreenGrabber
2. Click "Capture" button (or use hotkey)
3. Select area on screen
4. **Expected Results:**
   - ✅ File saved to configured folder (~/Pictures/Screen Grabber by default)
   - ✅ File appears in Finder at save location
   - ✅ Console shows: `[CAPTURE] ✅ Saved to: /path/to/file.png`
   - ✅ Console shows: `[CAPTURE] ✅ Added to history database`

### Test 2: Recent Captures UI Update
1. Take a screenshot (any method)
2. Look at menu bar Recent Captures section
3. **Expected Results:**
   - ✅ "No Screenshots Yet" message disappears
   - ✅ Screenshot thumbnail appears in list
   - ✅ Count badge shows "1" (or higher)
   - ✅ Console shows: `[MENU] ✅ Loaded N screenshots from database`

### Test 3: Clipboard Toggle - ON
1. Open CapturePanel settings
2. Enable "Copy to Clipboard" toggle
3. Take a screenshot
4. Open TextEdit or another app
5. Press Cmd+V to paste
6. **Expected Results:**
   - ✅ Image pastes successfully
   - ✅ Console shows: `[CAPTURE] 📋 Copy to clipboard is enabled, copying...`
   - ✅ Console shows: `[CAPTURE] ✅ Successfully copied to clipboard`

### Test 4: Clipboard Toggle - OFF
1. Open CapturePanel settings
2. Disable "Copy to Clipboard" toggle
3. Take a screenshot
4. Try pasting in another app
5. **Expected Results:**
   - ✅ Nothing pastes (or previous clipboard content)
   - ✅ Console shows: `[CAPTURE] ℹ️ Copy to clipboard is disabled, skipping...`

### Test 5: Preview in Editor Toggle
1. Enable "Preview in Editor" toggle
2. Take a screenshot
3. **Expected Results:**
   - ✅ Editor window opens automatically
   - ✅ Screenshot displayed in editor
   - ✅ File still saved to disk
   
4. Disable "Preview in Editor" toggle
5. Take another screenshot
6. **Expected Results:**
   - ✅ Editor does NOT open
   - ✅ File saved to disk
   - ✅ Recent Captures updates

### Test 6: Time Delay
1. Enable "Time Delay" toggle
2. Set delay to 3 seconds
3. Click "Capture"
4. Watch for countdown
5. **Expected Results:**
   - ✅ 3-second delay before area selector appears
   - ✅ Console shows: `[CAPTURE] ⏱️ Applying 3s delay...`
   - ✅ Capture completes after delay

### Test 7: Include Cursor
1. Enable "Include Cursor" toggle
2. Take a screenshot with cursor visible
3. Open the saved image
4. **Expected Results:**
   - ✅ Cursor visible in screenshot

### Test 8: Settings Persistence
1. Enable all toggles:
   - Copy to Clipboard: ON
   - Preview in Editor: ON
   - Time Delay: ON (5 seconds)
   - Include Cursor: ON
2. Quit ScreenGrabber
3. Relaunch ScreenGrabber
4. Check CapturePanel
5. **Expected Results:**
   - ✅ All toggles still enabled
   - ✅ Time delay still set to 5 seconds
   - ✅ Settings preserved across launches

### Test 9: Multiple Captures
1. Take 5 screenshots in rapid succession
2. Check save folder
3. Check Recent Captures
4. **Expected Results:**
   - ✅ All 5 files saved with unique names
   - ✅ All 5 appear in Recent Captures
   - ✅ No files overwritten
   - ✅ Count badge shows "5"

### Test 10: Invalid Save Path Handling
1. Open Settings
2. Set custom save location to invalid path (e.g., `/nonexistent/folder`)
3. Take a screenshot
4. **Expected Results:**
   - ✅ Error alert shown
   - ✅ Option to choose new folder
   - ✅ Falls back to default location
   - ✅ Screenshot still saved (to fallback)

## Console Log Verification

### Successful Capture Logs:
```
[CAPTURE] 🎬 Starting capture: Selected Area
[CAPTURE] 📐 Starting area selection...
[CAPTURE] ✅ Selected area: (x, y, width, height)
[CAPTURE] 💾 Saving capture...
[CAPTURE] ✅ Saved to: /Users/.../Screen Grabber/Screenshot_Area_2026-01-25_14-30-15.png
[CAPTURE] 📊 File size: 1.2 MB
[CAPTURE] ✅ Added to history database
[CAPTURE] 📋 Copy to clipboard is enabled, copying...
[CAPTURE] ✅ Successfully copied to clipboard
[CAPTURE] ✅ Thumbnails generated
[CAPTURE] ✅ Capture complete: Screenshot_Area_2026-01-25_14-30-15.png
[MENU] 🔄 Loading recent screenshots...
[MENU] ✅ Loaded 1 screenshots from database
[MENU] 📊 Updated with 1 screenshots from CaptureHistoryStore
```

### Clipboard Disabled Logs:
```
[CAPTURE] ℹ️ Copy to clipboard is disabled, skipping...
```

### Error Logs (if problems):
```
[CAPTURE] ❌ Failed to save image: ...
[CAPTURE] ❌ Failed to copy to clipboard: ...
[MENU] ⚠️ Failed to load recent captures
```

## File System Verification

### Default Save Location:
```
~/Pictures/Screen Grabber/
```

### File Naming Convention:
```
Screenshot_Area_2026-01-25_14-30-15.png
Screenshot_Window_2026-01-25_14-31-20.png
Screenshot_Screen_2026-01-25_14-32-45.png
Screenshot_Scrolling_2026-01-25_14-33-10.png
```

### Metadata Check:
```bash
# Check file size
ls -lh ~/Pictures/Screen\ Grabber/

# Check extended attributes (OCR text)
xattr -l ~/Pictures/Screen\ Grabber/Screenshot_*.png

# Verify PNG format
file ~/Pictures/Screen\ Grabber/Screenshot_*.png
```

## Database Verification

### SwiftData Console:
If you have access to the SwiftData database, verify:
- Screenshots table has entries
- Timestamps are correct
- File paths match actual files
- Thumbnails generated

### SQL Query (if using SQLite viewer):
```sql
SELECT filename, timestamp, fileSize, captureType 
FROM Screenshot 
ORDER BY timestamp DESC 
LIMIT 10;
```

## Common Issues & Solutions

### Issue: Screenshots not appearing in Recent Captures
**Solution:**
- Check console for `[MENU] ✅ Loaded N screenshots`
- Verify files exist in save folder
- Restart app to refresh database
- Check ModelContext is being passed correctly

### Issue: Clipboard not working
**Solution:**
- Verify toggle is ON in CapturePanel
- Check console for clipboard logs
- Try pasting in multiple apps
- Verify NSPasteboard permissions

### Issue: Files not saving
**Solution:**
- Check save path exists: `~/Pictures/Screen Grabber`
- Verify write permissions
- Check disk space
- Review error alerts
- Look for `[CAPTURE] ❌` in console

### Issue: Settings not persisting
**Solution:**
- Verify using `@ObservedObject var settingsModel = SettingsModel.shared`
- Check UserDefaults: `defaults read com.yourcompany.ScreenGrabber`
- Not using local `@State` for toggles
- SettingsModel is @MainActor

## Performance Benchmarks

### Expected Timings:
- Area selection to file save: < 1 second
- Thumbnail generation: 1-2 seconds (async)
- UI update after capture: < 100ms
- Clipboard copy: < 100ms

### Memory Usage:
- Base app: ~50-100 MB
- During capture: +20-50 MB (temporary)
- After 100 captures: < 200 MB

## Regression Testing

After any changes, re-run all 10 tests above to ensure:
- No new bugs introduced
- All features still work
- Performance remains acceptable
- Error handling still robust

## Automated Testing (Future)

Consider adding Swift Testing tests for:
- File save operations
- Clipboard operations
- Settings persistence
- History management
- Error handling paths

Example:
```swift
import Testing

@Suite("Screenshot Capture")
struct ScreenshotCaptureTests {
    
    @Test("File saves to correct location")
    func testFileSave() async throws {
        let manager = ScreenCaptureManager.shared
        let settings = SettingsModel.shared
        let saveURL = settings.effectiveSaveURL
        
        // Take screenshot
        // Verify file exists
        // Clean up
    }
    
    @Test("Clipboard toggle works")
    func testClipboard() async throws {
        // Enable toggle
        // Take screenshot
        // Verify clipboard has image
    }
}
```

## Sign-Off Checklist

Before marking this as complete:
- [ ] All 10 manual tests pass
- [ ] Console logs show expected output
- [ ] Files save to correct location
- [ ] Recent Captures updates
- [ ] Clipboard works when enabled
- [ ] Settings persist
- [ ] Error handling tested
- [ ] Performance acceptable
- [ ] No memory leaks
- [ ] Documentation updated
