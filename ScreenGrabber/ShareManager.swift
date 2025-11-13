//
//  ShareManager.swift
//  ScreenGrabber
//
//  Quick share extensions for cloud services and social platforms
//

import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Share Service Types
enum ShareServiceType: String, CaseIterable, Codable {
    // Cloud Storage
    case dropbox = "dropbox"
    case googleDrive = "google_drive"
    case iCloudDrive = "icloud_drive"
    case oneDrive = "onedrive"

    // Social Media
    case twitter = "twitter"
    case mastodon = "mastodon"
    case reddit = "reddit"

    // Communication
    case slack = "slack"
    case discord = "discord"
    case teams = "teams"
    case telegram = "telegram"

    // Issue Tracking & Development
    case github = "github"
    case gitlab = "gitlab"
    case jira = "jira"

    // Image Hosting
    case imgur = "imgur"
    case cloudinary = "cloudinary"

    // Other
    case email = "email"
    case airdrop = "airdrop"
    case clipboard = "clipboard"

    var displayName: String {
        switch self {
        case .dropbox: return "Dropbox"
        case .googleDrive: return "Google Drive"
        case .iCloudDrive: return "iCloud Drive"
        case .oneDrive: return "OneDrive"
        case .twitter: return "Twitter/X"
        case .mastodon: return "Mastodon"
        case .reddit: return "Reddit"
        case .slack: return "Slack"
        case .discord: return "Discord"
        case .teams: return "Microsoft Teams"
        case .telegram: return "Telegram"
        case .github: return "GitHub"
        case .gitlab: return "GitLab"
        case .jira: return "Jira"
        case .imgur: return "Imgur"
        case .cloudinary: return "Cloudinary"
        case .email: return "Email"
        case .airdrop: return "AirDrop"
        case .clipboard: return "Clipboard"
        }
    }

    var icon: String {
        switch self {
        case .dropbox: return "cloud.fill"
        case .googleDrive: return "cloud.fill"
        case .iCloudDrive: return "icloud.fill"
        case .oneDrive: return "cloud.fill"
        case .twitter: return "bird"
        case .mastodon: return "bubble.left.and.bubble.right"
        case .reddit: return "bubble.left"
        case .slack: return "message.fill"
        case .discord: return "message.fill"
        case .teams: return "person.3.fill"
        case .telegram: return "paperplane.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .gitlab: return "chevron.left.forwardslash.chevron.right"
        case .jira: return "checkmark.circle.fill"
        case .imgur: return "photo.fill"
        case .cloudinary: return "photo.on.rectangle"
        case .email: return "envelope.fill"
        case .airdrop: return "airplayaudio"
        case .clipboard: return "doc.on.clipboard"
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .clipboard, .airdrop, .email, .iCloudDrive:
            return false
        default:
            return true
        }
    }
}

// MARK: - Share Service Configuration
struct ShareServiceConfig: Codable, Identifiable {
    let id: UUID
    let serviceType: ShareServiceType
    var isEnabled: Bool
    var apiKey: String?
    var apiSecret: String?
    var accessToken: String?
    var refreshToken: String?
    var username: String?
    var defaultDestination: String? // Folder, channel, etc.
    var customSettings: [String: String]

    init(serviceType: ShareServiceType) {
        self.id = UUID()
        self.serviceType = serviceType
        self.isEnabled = false
        self.apiKey = nil
        self.apiSecret = nil
        self.accessToken = nil
        self.refreshToken = nil
        self.username = nil
        self.defaultDestination = nil
        self.customSettings = [:]
    }
}

// MARK: - Share Result
struct ShareResult {
    let success: Bool
    let url: String?
    let message: String
    let serviceType: ShareServiceType
}

// MARK: - Share Manager
class ShareManager: ObservableObject {
    static let shared = ShareManager()

    @Published var serviceConfigs: [ShareServiceConfig] = []
    @Published var isSharing: Bool = false
    @Published var shareHistory: [ShareHistoryItem] = []

    private let userDefaultsKey = "com.screengrabber.share_services"
    private let historyKey = "com.screengrabber.share_history"
    private let maxHistoryItems = 100

    private init() {
        loadConfigurations()
        loadHistory()
    }

    // MARK: - Configuration Management

    private func loadConfigurations() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ShareServiceConfig].self, from: data) {
            serviceConfigs = decoded
        } else {
            // Create default configurations
            serviceConfigs = ShareServiceType.allCases.map { ShareServiceConfig(serviceType: $0) }
            saveConfigurations()
        }
    }

    private func saveConfigurations() {
        if let encoded = try? JSONEncoder().encode(serviceConfigs) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    func updateServiceConfig(_ config: ShareServiceConfig) {
        if let index = serviceConfigs.firstIndex(where: { $0.id == config.id }) {
            serviceConfigs[index] = config
            saveConfigurations()
        }
    }

    func enableService(_ serviceType: ShareServiceType, enabled: Bool = true) {
        if let index = serviceConfigs.firstIndex(where: { $0.serviceType == serviceType }) {
            serviceConfigs[index].isEnabled = enabled
            saveConfigurations()
        }
    }

    // MARK: - Sharing

    func share(imageURL: URL, to serviceType: ShareServiceType, completion: @escaping (ShareResult) -> Void) {
        guard let config = serviceConfigs.first(where: { $0.serviceType == serviceType }),
              config.isEnabled else {
            completion(ShareResult(
                success: false,
                url: nil,
                message: "Service not enabled",
                serviceType: serviceType
            ))
            return
        }

        isSharing = true

        switch serviceType {
        case .clipboard:
            shareToClipboard(imageURL: imageURL, completion: completion)
        case .airdrop:
            shareViaAirDrop(imageURL: imageURL, completion: completion)
        case .email:
            shareViaEmail(imageURL: imageURL, completion: completion)
        case .iCloudDrive:
            shareToiCloudDrive(imageURL: imageURL, config: config, completion: completion)
        case .dropbox:
            shareToDropbox(imageURL: imageURL, config: config, completion: completion)
        case .imgur:
            shareToImgur(imageURL: imageURL, config: config, completion: completion)
        case .slack:
            shareToSlack(imageURL: imageURL, config: config, completion: completion)
        case .discord:
            shareToDiscord(imageURL: imageURL, config: config, completion: completion)
        case .github:
            shareToGitHub(imageURL: imageURL, config: config, completion: completion)
        default:
            shareViaSystemPicker(imageURL: imageURL, serviceType: serviceType, completion: completion)
        }
    }

    // MARK: - Built-in Sharing Methods

    private func shareToClipboard(imageURL: URL, completion: @escaping (ShareResult) -> Void) {
        guard let image = NSImage(contentsOf: imageURL) else {
            completion(ShareResult(success: false, url: nil, message: "Failed to load image", serviceType: .clipboard))
            isSharing = false
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])

        addToHistory(url: imageURL.path, service: .clipboard, success: true)
        completion(ShareResult(success: true, url: nil, message: "Copied to clipboard", serviceType: .clipboard))
        isSharing = false
    }

    private func shareViaAirDrop(imageURL: URL, completion: @escaping (ShareResult) -> Void) {
        let picker = NSSharingServicePicker(items: [imageURL])

        if let mainWindow = NSApp.keyWindow {
            picker.show(relativeTo: .zero, of: mainWindow.contentView!, preferredEdge: .minY)
            addToHistory(url: imageURL.path, service: .airdrop, success: true)
            completion(ShareResult(success: true, url: nil, message: "AirDrop initiated", serviceType: .airdrop))
        } else {
            completion(ShareResult(success: false, url: nil, message: "No window available", serviceType: .airdrop))
        }

        isSharing = false
    }

    private func shareViaEmail(imageURL: URL, completion: @escaping (ShareResult) -> Void) {
        let service = NSSharingService(named: .composeEmail)
        service?.recipients = []
        service?.subject = "Screenshot from ScreenGrabber"

        if service?.canPerform(withItems: [imageURL]) == true {
            service?.perform(withItems: [imageURL])
            addToHistory(url: imageURL.path, service: .email, success: true)
            completion(ShareResult(success: true, url: nil, message: "Email composer opened", serviceType: .email))
        } else {
            completion(ShareResult(success: false, url: nil, message: "Email not configured", serviceType: .email))
        }

        isSharing = false
    }

    private func shareToiCloudDrive(imageURL: URL, config: ShareServiceConfig, completion: @escaping (ShareResult) -> Void) {
        let fileManager = FileManager.default

        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("Screenshots") else {
            completion(ShareResult(success: false, url: nil, message: "iCloud Drive not available", serviceType: .iCloudDrive))
            isSharing = false
            return
        }

        do {
            try fileManager.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
            let destinationURL = iCloudURL.appendingPathComponent(imageURL.lastPathComponent)
            try fileManager.copyItem(at: imageURL, to: destinationURL)

            addToHistory(url: destinationURL.path, service: .iCloudDrive, success: true)
            completion(ShareResult(success: true, url: destinationURL.absoluteString, message: "Uploaded to iCloud Drive", serviceType: .iCloudDrive))
        } catch {
            completion(ShareResult(success: false, url: nil, message: error.localizedDescription, serviceType: .iCloudDrive))
        }

        isSharing = false
    }

    // MARK: - Cloud Service Integrations

    private func shareToDropbox(imageURL: URL, config: ShareServiceConfig, completion: @escaping (ShareResult) -> Void) {
        guard let accessToken = config.accessToken else {
            completion(ShareResult(success: false, url: nil, message: "Not authenticated", serviceType: .dropbox))
            isSharing = false
            return
        }

        // Dropbox API v2 upload
        let uploadURL = URL(string: "https://content.dropboxapi.com/2/files/upload")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let dropboxPath = "/Screenshots/\(imageURL.lastPathComponent)"
        let apiArg = ["path": dropboxPath, "mode": "add", "autorename": true]
        if let jsonData = try? JSONSerialization.data(withJSONObject: apiArg),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            request.setValue(jsonString, forHTTPHeaderField: "Dropbox-API-Arg")
        }

        guard let imageData = try? Data(contentsOf: imageURL) else {
            completion(ShareResult(success: false, url: nil, message: "Failed to read image", serviceType: .dropbox))
            isSharing = false
            return
        }

        let task = URLSession.shared.uploadTask(with: request, from: imageData) { data, response, error in
            DispatchQueue.main.async {
                self.isSharing = false

                if let error = error {
                    completion(ShareResult(success: false, url: nil, message: error.localizedDescription, serviceType: .dropbox))
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self.addToHistory(url: imageURL.path, service: .dropbox, success: true)
                    completion(ShareResult(success: true, url: dropboxPath, message: "Uploaded to Dropbox", serviceType: .dropbox))
                } else {
                    completion(ShareResult(success: false, url: nil, message: "Upload failed", serviceType: .dropbox))
                }
            }
        }

        task.resume()
    }

    private func shareToImgur(imageURL: URL, config: ShareServiceConfig, completion: @escaping (ShareResult) -> Void) {
        guard let clientId = config.apiKey else {
            completion(ShareResult(success: false, url: nil, message: "API key not configured", serviceType: .imgur))
            isSharing = false
            return
        }

        let uploadURL = URL(string: "https://api.imgur.com/3/image")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Client-ID \(clientId)", forHTTPHeaderField: "Authorization")

        guard let imageData = try? Data(contentsOf: imageURL),
              let base64 = imageData.base64EncodedString().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(ShareResult(success: false, url: nil, message: "Failed to encode image", serviceType: .imgur))
            isSharing = false
            return
        }

        let body = "image=\(base64)"
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSharing = false

                if let error = error {
                    completion(ShareResult(success: false, url: nil, message: error.localizedDescription, serviceType: .imgur))
                    return
                }

                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataDict = json["data"] as? [String: Any],
                   let link = dataDict["link"] as? String {
                    self.addToHistory(url: imageURL.path, service: .imgur, success: true, shareURL: link)
                    completion(ShareResult(success: true, url: link, message: "Uploaded to Imgur", serviceType: .imgur))
                } else {
                    completion(ShareResult(success: false, url: nil, message: "Upload failed", serviceType: .imgur))
                }
            }
        }

        task.resume()
    }

    private func shareToSlack(imageURL: URL, config: ShareServiceConfig, completion: @escaping (ShareResult) -> Void) {
        guard let accessToken = config.accessToken,
              let channel = config.defaultDestination else {
            completion(ShareResult(success: false, url: nil, message: "Not configured", serviceType: .slack))
            isSharing = false
            return
        }

        // Slack files.upload API
        let uploadURL = URL(string: "https://slack.com/api/files.upload")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add channels parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"channels\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(channel)\r\n".data(using: .utf8)!)

        // Add file
        if let imageData = try? Data(contentsOf: imageURL) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(imageURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSharing = false

                if let error = error {
                    completion(ShareResult(success: false, url: nil, message: error.localizedDescription, serviceType: .slack))
                    return
                }

                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let ok = json["ok"] as? Bool, ok {
                    self.addToHistory(url: imageURL.path, service: .slack, success: true)
                    completion(ShareResult(success: true, url: nil, message: "Shared to Slack", serviceType: .slack))
                } else {
                    completion(ShareResult(success: false, url: nil, message: "Upload failed", serviceType: .slack))
                }
            }
        }

        task.resume()
    }

    private func shareToDiscord(imageURL: URL, config: ShareServiceConfig, completion: @escaping (ShareResult) -> Void) {
        guard let webhookURL = config.customSettings["webhook_url"] else {
            completion(ShareResult(success: false, url: nil, message: "Webhook URL not configured", serviceType: .discord))
            isSharing = false
            return
        }

        guard let url = URL(string: webhookURL) else {
            completion(ShareResult(success: false, url: nil, message: "Invalid webhook URL", serviceType: .discord))
            isSharing = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        if let imageData = try? Data(contentsOf: imageURL) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(imageURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSharing = false

                if let error = error {
                    completion(ShareResult(success: false, url: nil, message: error.localizedDescription, serviceType: .discord))
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    self.addToHistory(url: imageURL.path, service: .discord, success: true)
                    completion(ShareResult(success: true, url: nil, message: "Shared to Discord", serviceType: .discord))
                } else {
                    completion(ShareResult(success: false, url: nil, message: "Upload failed", serviceType: .discord))
                }
            }
        }

        task.resume()
    }

    private func shareToGitHub(imageURL: URL, config: ShareServiceConfig, completion: @escaping (ShareResult) -> Void) {
        // GitHub Gist or Issue attachment
        guard let accessToken = config.accessToken else {
            completion(ShareResult(success: false, url: nil, message: "Not authenticated", serviceType: .github))
            isSharing = false
            return
        }

        // For simplicity, create a public Gist with the image
        let gistURL = URL(string: "https://api.github.com/gists")!
        var request = URLRequest(url: gistURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard let imageData = try? Data(contentsOf: imageURL) else {
            completion(ShareResult(success: false, url: nil, message: "Failed to read image", serviceType: .github))
            isSharing = false
            return
        }

        let base64Image = imageData.base64EncodedString()
        let gistContent = """
        # Screenshot from ScreenGrabber

        ![Screenshot](data:image/png;base64,\(base64Image))
        """

        let gist: [String: Any] = [
            "description": "Screenshot from ScreenGrabber",
            "public": true,
            "files": [
                "screenshot.md": ["content": gistContent]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: gist) else {
            completion(ShareResult(success: false, url: nil, message: "Failed to create request", serviceType: .github))
            isSharing = false
            return
        }

        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isSharing = false

                if let error = error {
                    completion(ShareResult(success: false, url: nil, message: error.localizedDescription, serviceType: .github))
                    return
                }

                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let htmlURL = json["html_url"] as? String {
                    self.addToHistory(url: imageURL.path, service: .github, success: true, shareURL: htmlURL)
                    completion(ShareResult(success: true, url: htmlURL, message: "Created GitHub Gist", serviceType: .github))
                } else {
                    completion(ShareResult(success: false, url: nil, message: "Upload failed", serviceType: .github))
                }
            }
        }

        task.resume()
    }

    private func shareViaSystemPicker(imageURL: URL, serviceType: ShareServiceType, completion: @escaping (ShareResult) -> Void) {
        let picker = NSSharingServicePicker(items: [imageURL])

        if let mainWindow = NSApp.keyWindow {
            picker.show(relativeTo: .zero, of: mainWindow.contentView!, preferredEdge: .minY)
            addToHistory(url: imageURL.path, service: serviceType, success: true)
            completion(ShareResult(success: true, url: nil, message: "Share picker opened", serviceType: serviceType))
        } else {
            completion(ShareResult(success: false, url: nil, message: "No window available", serviceType: serviceType))
        }

        isSharing = false
    }

    // MARK: - History

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([ShareHistoryItem].self, from: data) {
            shareHistory = decoded
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(shareHistory) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }

    private func addToHistory(url: String, service: ShareServiceType, success: Bool, shareURL: String? = nil) {
        let item = ShareHistoryItem(
            fileURL: url,
            serviceType: service,
            shareDate: Date(),
            success: success,
            shareURL: shareURL
        )

        shareHistory.insert(item, at: 0)

        // Keep only the most recent items
        if shareHistory.count > maxHistoryItems {
            shareHistory = Array(shareHistory.prefix(maxHistoryItems))
        }

        saveHistory()
    }

    func clearHistory() {
        shareHistory.removeAll()
        saveHistory()
    }
}

// MARK: - Share History Item
struct ShareHistoryItem: Codable, Identifiable {
    let id: UUID
    let fileURL: String
    let serviceType: ShareServiceType
    let shareDate: Date
    let success: Bool
    let shareURL: String?

    init(fileURL: String, serviceType: ShareServiceType, shareDate: Date, success: Bool, shareURL: String? = nil) {
        self.id = UUID()
        self.fileURL = fileURL
        self.serviceType = serviceType
        self.shareDate = shareDate
        self.success = success
        self.shareURL = shareURL
    }
}
