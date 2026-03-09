//
//  ARCHITECTURE_DIAGRAM.md
//  ScreenGrabber
//
//  Visual architecture diagrams for screenshot capture system
//

# ScreenGrabber Architecture Diagrams

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         ScreenGrabber                            │
│                                                                   │
│  ┌──────────────┐      ┌──────────────┐      ┌──────────────┐  │
│  │  MenuBar UI  │◄────►│   Settings   │◄────►│   Storage    │  │
│  │              │      │    Model     │      │   Services   │  │
│  └──────┬───────┘      └──────┬───────┘      └──────┬───────┘  │
│         │                     │                     │           │
│         ├─────────────────────┼─────────────────────┘           │
│         │                     │                                 │
│  ┌──────▼──────────────────────▼──────────────────────────┐    │
│  │          ScreenCaptureManager (Coordinator)            │    │
│  │                                                          │    │
│  │  • captureScreen()                                      │    │
│  │  • saveCapture()                                        │    │
│  │  • handleOpenOption()                                   │    │
│  └──────┬───────────────┬───────────────┬──────────────────┘    │
│         │               │               │                       │
│  ┌──────▼──────┐ ┌─────▼──────┐ ┌──────▼─────────┐            │
│  │  Capture    │ │   File     │ │   Clipboard    │            │
│  │  History    │ │   Store    │ │   Service      │            │
│  │  Store      │ │            │ │                │            │
│  └─────────────┘ └────────────┘ └────────────────┘            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Capture Flow (Detailed)

```
┌─────────────┐
│    User     │
│ Clicks      │
│ "Capture"   │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│  ScreenCaptureManager.captureScreen()                   │
│                                                          │
│  1. Validate permissions                                │
│  2. Apply time delay (if enabled)                       │
│  3. Show selector (area/window/screen)                  │
└──────┬──────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────────────┐
│  Capture Methods                                         │
│                                                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │  Area    │  │  Window  │  │  Screen  │             │
│  │ Selector │  │  Picker  │  │  Capture │             │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘             │
│       └─────────────┼─────────────┘                     │
└─────────────────────┼───────────────────────────────────┘
                      │
                      ▼
              ┌───────────────┐
              │ CaptureResult │
              │  - image      │
              │  - size       │
              │  - metadata   │
              └───────┬───────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│  ScreenCaptureManager.saveCapture()                     │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Step 1: Save File                              │   │
│  │  ┌──────────────────────────────────────────┐   │   │
│  │  │ CaptureFileStore.saveImage()             │   │   │
│  │  │  • Get save location                     │   │   │
│  │  │  • Validate/create folder                │   │   │
│  │  │  • Generate unique filename              │   │   │
│  │  │  • Convert to PNG                        │   │   │
│  │  │  • Write to disk (atomic)                │   │   │
│  │  │  • Return Result<URL, Error>             │   │   │
│  │  └──────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                          │
│  ┌─────────────────────────────────────────────────┐   │
│  │  Step 2: Save to Database                       │   │
│  │  ┌──────────────────────────────────────────┐   │   │
│  │  │ CaptureHistoryStore.addCapture()         │   │   │
│  │  │  • Create Screenshot model               │   │   │
│  │  │  • Insert into SwiftData                 │   │   │
│  │  │  • Save ModelContext                     │   │   │
│  │  │  • Reload recent captures                │   │   │
│  │  │  • Post notification                     │   │   │
│  │  │  • Return Result<Screenshot, Error>      │   │   │
│  │  └──────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────┘   │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  Post-Save Actions                                       │
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  Clipboard   │  │  Open in     │  │  Show        │  │
│  │  (if enabled)│  │  Editor      │  │  Notification│  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  Notification System                                     │
│                                                          │
│  NotificationCenter.default.post(                        │
│    name: .screenshotCaptured                            │
│  )                                                       │
│                                                          │
│  NotificationCenter.default.post(                        │
│    name: .screenshotSavedToHistory                      │
│  )                                                       │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│  UI Updates                                              │
│                                                          │
│  MenuBarContentView.onReceive(.screenshotCaptured) {    │
│    loadRecentScreenshots()                              │
│  }                                                       │
│                                                          │
│  MenuBarContentView.onReceive(.screenshotSavedToHistory){│
│    loadRecentScreenshots()                              │
│  }                                                       │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
                  ┌────────────────┐
                  │ Recent Captures│
                  │ List Updated   │
                  │      ✅        │
                  └────────────────┘
```

## Settings Data Flow

```
┌──────────────────────────────────────────────────────────┐
│  CapturePanel (UI)                                        │
│                                                           │
│  @ObservedObject var settingsModel = SettingsModel.shared│
│                                                           │
│  Toggle("Copy to Clipboard",                             │
│    isOn: $settingsModel.copyToClipboardEnabled)          │
│                                                           │
│  Toggle("Preview in Editor",                             │
│    isOn: $settingsModel.previewInEditorEnabled)          │
│                                                           │
│  Toggle("Time Delay",                                    │
│    isOn: $settingsModel.timeDelayEnabled)                │
└────────────────┬─────────────────────────────────────────┘
                 │
                 │ Binds to
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│  SettingsModel (Shared Instance)                         │
│                                                           │
│  @AppStorage("copyToClipboardEnabled")                   │
│  var copyToClipboardEnabled: Bool = false                │
│                                                           │
│  @AppStorage("previewInEditorEnabled")                   │
│  var previewInEditorEnabled: Bool = false                │
│                                                           │
│  @AppStorage("timeDelayEnabled")                         │
│  var timeDelayEnabled: Bool = false                      │
│                                                           │
│  @AppStorage("timeDelaySeconds")                         │
│  var timeDelaySeconds: Double = 3.0                      │
└────────────────┬─────────────────────────────────────────┘
                 │
                 │ Persists to
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│  UserDefaults                                             │
│                                                           │
│  com.yourcompany.ScreenGrabber                           │
│    copyToClipboardEnabled = true                         │
│    previewInEditorEnabled = false                        │
│    timeDelayEnabled = true                               │
│    timeDelaySeconds = 5.0                                │
└────────────────┬─────────────────────────────────────────┘
                 │
                 │ Read by
                 │
                 ▼
┌──────────────────────────────────────────────────────────┐
│  ScreenCaptureManager                                     │
│                                                           │
│  let settings = await MainActor.run {                    │
│    SettingsModel.shared                                  │
│  }                                                        │
│                                                           │
│  if settings.copyToClipboardEnabled {                    │
│    await CaptureClipboardService.shared.copyToClipboard()│
│  }                                                        │
│                                                           │
│  if settings.timeDelayEnabled {                          │
│    try await Task.sleep(for: .seconds(                   │
│      settings.timeDelaySeconds                           │
│    ))                                                     │
│  }                                                        │
└──────────────────────────────────────────────────────────┘
```

## Storage Architecture

```
┌──────────────────────────────────────────────────────────┐
│  Storage Layer                                            │
│                                                           │
│  ┌────────────────────┐        ┌────────────────────┐   │
│  │  File System       │        │  SwiftData         │   │
│  │                    │        │  Database          │   │
│  │  ~/Pictures/       │        │                    │   │
│  │  Screen Grabber/   │        │  Screenshot Model  │   │
│  │    Screenshot_*.png│        │    - filename      │   │
│  │    (PNG files)     │        │    - filePath      │   │
│  │                    │        │    - timestamp     │   │
│  │                    │        │    - fileSize      │   │
│  │                    │        │    - metadata      │   │
│  └────────┬───────────┘        └─────────┬──────────┘   │
│           │                              │               │
│           │                              │               │
│  ┌────────▼──────────┐        ┌─────────▼──────────┐   │
│  │ CaptureFileStore  │        │ CaptureHistoryStore│   │
│  │                   │        │                    │   │
│  │ • saveImage()     │        │ • addCapture()     │   │
│  │ • deleteImage()   │        │ • loadRecentC...() │   │
│  │ • validation      │        │ • deleteCapture()  │   │
│  │ • error handling  │        │ • updateAnn...()   │   │
│  └───────────────────┘        └────────────────────┘   │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

## Error Handling Flow

```
┌─────────────────────┐
│  Save Operation     │
└──────────┬──────────┘
           │
           ▼
┌──────────────────────────────────────────────┐
│  CaptureFileStore.saveImage()                │
└──────────┬───────────────────────────────────┘
           │
           ├─ Success ──────────────────────────┐
           │                                     │
           │                                     ▼
           │                          ┌──────────────────┐
           │                          │ Return           │
           │                          │ .success(fileURL)│
           │                          └──────────────────┘
           │
           └─ Failure ──────────────────────────┐
                                                 │
                                                 ▼
                              ┌──────────────────────────────┐
                              │ Error Type Detection         │
                              └──────┬───────────────────────┘
                                     │
           ┌─────────────────────────┼─────────────────────────┐
           │                         │                         │
           ▼                         ▼                         ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Folder Error     │  │ Permission Error │  │ Disk Full        │
│                  │  │                  │  │                  │
│ • Create folder  │  │ • Show picker    │  │ • Show storage   │
│ • Use fallback   │  │ • Select new     │  │   settings       │
│ • Alert user     │  │   location       │  │ • Alert user     │
└──────────────────┘  └──────────────────┘  └──────────────────┘
           │                         │                         │
           └─────────────────────────┼─────────────────────────┘
                                     │
                                     ▼
                          ┌──────────────────┐
                          │ Return           │
                          │ .failure(error)  │
                          └──────────────────┘
```

## Notification Flow

```
┌─────────────────────────────────────────────────────────┐
│  Notification Publishers & Subscribers                   │
└─────────────────────────────────────────────────────────┘

Publisher: ScreenCaptureManager
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
NotificationCenter.default.post(
  name: .screenshotCaptured,
  object: Screenshot,
  userInfo: ["url": URL]
)

NotificationCenter.default.post(
  name: .screenshotSavedToHistory,
  object: Screenshot,
  userInfo: ["url": URL]
)

                    │
                    │ Distributed to all subscribers
                    │
    ┌───────────────┼───────────────┐
    │               │               │
    ▼               ▼               ▼

Subscriber 1    Subscriber 2    Subscriber 3
━━━━━━━━━━━    ━━━━━━━━━━━    ━━━━━━━━━━━
MenuBar         Library         Editor
ContentView     View            View
    │               │               │
    ▼               ▼               ▼
Reload          Refresh         Update
Recent          Grid            Toolbar
Captures        Layout          State
```

## Component Relationships

```
                    ┌──────────────────┐
                    │  SettingsModel   │
                    │  (Singleton)     │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
      ┌────────────┐  ┌────────────┐  ┌────────────┐
      │  Capture   │  │   Menu     │  │  Settings  │
      │   Panel    │  │    Bar     │  │   Window   │
      └─────┬──────┘  └─────┬──────┘  └─────┬──────┘
            │               │               │
            └───────────────┼───────────────┘
                            │
                            ▼
                ┌──────────────────────┐
                │ ScreenCaptureManager │
                │   (Coordinator)      │
                └───────┬──────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
        ▼               ▼               ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ CaptureFile  │ │ CaptureHist  │ │ CaptureClip  │
│    Store     │ │    Store     │ │   Service    │
└──────────────┘ └──────────────┘ └──────────────┘
```

## Thread Safety Model

```
┌─────────────────────────────────────────────────────────┐
│  Thread Safety & Concurrency                             │
└─────────────────────────────────────────────────────────┘

@MainActor Components
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• SettingsModel
• CaptureHistoryStore
• CaptureClipboardService
• All SwiftUI Views

actor Components
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• CaptureFileStore (isolated)

Mixed Components
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• ScreenCaptureManager (@MainActor class)
  - UI updates on main thread
  - File I/O on background threads
  - Uses async/await for coordination

Data Flow:
Main Thread → Background Thread → Main Thread
    │              │                  │
    ▼              ▼                  ▼
  Start        File Save          UI Update
  Capture     (CaptureFileStore)  (Notifications)
```

## State Management

```
┌──────────────────────────────────────────────────────────┐
│  State Sources                                            │
└──────────────────────────────────────────────────────────┘

Persistent State (UserDefaults)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SettingsModel (@AppStorage)
• copyToClipboardEnabled
• previewInEditorEnabled
• timeDelayEnabled
• timeDelaySeconds
• includeCursor
• customSaveLocationPath

Database State (SwiftData)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Screenshot Model
• filename
• filePath
• timestamp
• fileSize
• metadata

Runtime State (@Published)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ScreenCaptureManager
• isCapturing
• lastCaptureURL
• captureProgress

CaptureHistoryStore
• recentCaptures

UI State (@State)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MenuBarContentView
• recentScreenshots (derived from database)
• showingEditor
• hoveredCaptureURL
```

---

**Legend:**
- `┌─┐` Box components
- `→` Data flow
- `▼` Vertical flow
- `━` Major sections
- `┼` Intersections
