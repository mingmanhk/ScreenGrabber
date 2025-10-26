//
//  SettingsView.swift
//  ScreenGrabber
//
//  Created by Victor Lam on 10/23/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var currentHotkey = "⌘⇧C"
    @State private var launchAtLogin = false
    @State private var showNotifications = true
    
    var body: some View {
        TabView {
            // General Settings
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Global Hotkey")
                        .font(.headline)
                    
                    HStack {
                        Text("Current hotkey:")
                        
                        Text(currentHotkey)
                            .font(.system(.body, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                        
                        Spacer()
                        

                    }
                    
                    Text("Press this key combination anywhere to capture a screenshot.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Preferences")
                        .font(.headline)
                    
                    Toggle("Launch at login", isOn: $launchAtLogin)
                    Toggle("Show notifications", isOn: $showNotifications)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Screenshots Folder")
                        .font(.headline)
                    
                    HStack {
                        Text("Location:")
                        Text("~/Pictures/ScreenGrabber")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Open in Finder") {
                            let folderURL = ScreenCaptureManager.shared.getScreenGrabberFolderURL()
                            NSWorkspace.shared.open(folderURL)
                        }
                    }
                    
                    Text("All screenshots are automatically saved to this folder.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .tabItem {
                Label("General", systemImage: "gear")
            }
            
            // About Tab
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("Screen Grabber")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("A powerful screenshot tool for macOS with editing capabilities and automatic file organization.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Global hotkey support", systemImage: "keyboard")
                        Label("Menu bar integration", systemImage: "menubar.rectangle")
                        Label("Automatic file saving", systemImage: "folder")
                        Label("Multiple capture methods", systemImage: "camera.fill")
                        Label("Built-in image editor", systemImage: "pencil.circle")
                        Label("Clipboard integration", systemImage: "doc.on.clipboard")
                    }
                    .font(.body)
                }
                
                Spacer()
                
                Text("© 2024 Screen Grabber. All rights reserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(minWidth: 450, minHeight: 400)
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        currentHotkey = UserDefaults.standard.string(forKey: "grabScreenHotkey") ?? "⌘⇧C"
        showNotifications = UserDefaults.standard.bool(forKey: "showNotifications")
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
    }
}


