# ScreenGrabber

<div align="center">

![ScreenGrabber Icon](https://img.shields.io/badge/macOS-Compatible-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-Latest-green)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

**A powerful, modern macOS screenshot application with global hotkey support and intelligent organization.**

<img src="Sources/ScreenGrabber.png" alt="ScreenGrabber App Screenshot" width="900" />

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
