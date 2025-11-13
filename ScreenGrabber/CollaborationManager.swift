//
//  CollaborationManager.swift
//  ScreenGrabber
//
//  Real-time collaboration for screenshot annotations
//

import Foundation
import Combine
import AppKit

// MARK: - Collaboration Session
struct CollaborationSession: Codable, Identifiable {
    let id: String
    let screenshotId: String
    let hostUserId: String
    let hostUsername: String
    let createdDate: Date
    var participants: [CollaborationParticipant]
    var isActive: Bool
    var sessionURL: String?
    var expiresAt: Date?

    init(screenshotId: String, hostUserId: String, hostUsername: String) {
        self.id = UUID().uuidString
        self.screenshotId = screenshotId
        self.hostUserId = hostUserId
        self.hostUsername = hostUsername
        self.createdDate = Date()
        self.participants = []
        self.isActive = true
        self.sessionURL = nil
        self.expiresAt = Calendar.current.date(byAdding: .hour, value: 24, to: Date())
    }
}

// MARK: - Collaboration Participant
struct CollaborationParticipant: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let joinedDate: Date
    var isActive: Bool
    var cursorPosition: CGPoint?
    var color: CodableColor

    init(id: String = UUID().uuidString, username: String, color: CodableColor = CodableColor(nsColor: .systemBlue)) {
        self.id = id
        self.username = username
        self.joinedDate = Date()
        self.isActive = true
        self.cursorPosition = nil
        self.color = color
    }

    static func == (lhs: CollaborationParticipant, rhs: CollaborationParticipant) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Collaboration Annotation
struct CollaborationAnnotation: Codable, Identifiable {
    let id: String
    let userId: String
    let username: String
    let annotationData: Data // Serialized DrawingAnnotation
    let createdDate: Date
    var modifiedDate: Date
    var isDeleted: Bool

    init(userId: String, username: String, annotationData: Data) {
        self.id = UUID().uuidString
        self.userId = userId
        self.username = username
        self.annotationData = annotationData
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.isDeleted = false
    }
}

// MARK: - Collaboration Message Types
enum CollaborationMessageType: String, Codable {
    case join = "join"
    case leave = "leave"
    case annotationAdded = "annotation_added"
    case annotationUpdated = "annotation_updated"
    case annotationDeleted = "annotation_deleted"
    case cursorMoved = "cursor_moved"
    case chat = "chat"
    case sync = "sync"
    case ping = "ping"
    case pong = "pong"
}

// MARK: - Collaboration Message
struct CollaborationMessage: Codable {
    let id: String
    let sessionId: String
    let userId: String
    let username: String
    let type: CollaborationMessageType
    let timestamp: Date
    let payload: Data?

    init(sessionId: String, userId: String, username: String, type: CollaborationMessageType, payload: Data? = nil) {
        self.id = UUID().uuidString
        self.sessionId = sessionId
        self.userId = userId
        self.username = username
        self.type = type
        self.timestamp = Date()
        self.payload = payload
    }
}

// MARK: - Collaboration Manager
class CollaborationManager: ObservableObject {
    static let shared = CollaborationManager()

    @Published var activeSessions: [CollaborationSession] = []
    @Published var currentSession: CollaborationSession?
    @Published var currentUserId: String
    @Published var currentUsername: String
    @Published var isConnected: Bool = false
    @Published var participants: [CollaborationParticipant] = []
    @Published var chatMessages: [ChatMessage] = []
    @Published var collaborativeAnnotations: [CollaborationAnnotation] = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var messageSubject = PassthroughSubject<CollaborationMessage, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var heartbeatTimer: Timer?

    private let serverURL = "wss://collaboration.screengrabber.app" // Replace with actual server
    private let userDefaultsKey = "com.screengrabber.user_id"
    private let usernameKey = "com.screengrabber.username"

    private init() {
        // Load or create user ID
        if let savedUserId = UserDefaults.standard.string(forKey: userDefaultsKey) {
            self.currentUserId = savedUserId
        } else {
            let newUserId = UUID().uuidString
            UserDefaults.standard.set(newUserId, forKey: userDefaultsKey)
            self.currentUserId = newUserId
        }

        // Load or create username
        if let savedUsername = UserDefaults.standard.string(forKey: usernameKey) {
            self.currentUsername = savedUsername
        } else {
            self.currentUsername = NSFullUserName()
            UserDefaults.standard.set(self.currentUsername, forKey: usernameKey)
        }

        setupMessageHandling()
    }

    // MARK: - Configuration

    func setUsername(_ username: String) {
        currentUsername = username
        UserDefaults.standard.set(username, forKey: usernameKey)
    }

    // MARK: - Session Management

    func createSession(for screenshot: Screenshot) -> CollaborationSession {
        let session = CollaborationSession(
            screenshotId: screenshot.filePath,
            hostUserId: currentUserId,
            hostUsername: currentUsername
        )

        activeSessions.append(session)
        return session
    }

    func joinSession(sessionId: String, completion: @escaping (Bool) -> Void) {
        // Connect to WebSocket server
        connectToServer(sessionId: sessionId) { success in
            if success {
                // Send join message
                let joinMessage = CollaborationMessage(
                    sessionId: sessionId,
                    userId: self.currentUserId,
                    username: self.currentUsername,
                    type: .join
                )
                self.sendMessage(joinMessage)
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    func leaveSession() {
        guard let session = currentSession else { return }

        let leaveMessage = CollaborationMessage(
            sessionId: session.id,
            userId: currentUserId,
            username: currentUsername,
            type: .leave
        )
        sendMessage(leaveMessage)

        disconnectFromServer()
        currentSession = nil
        participants.removeAll()
        chatMessages.removeAll()
        collaborativeAnnotations.removeAll()
    }

    func endSession(sessionId: String) {
        if let index = activeSessions.firstIndex(where: { $0.id == sessionId }) {
            activeSessions[index].isActive = false
            if currentSession?.id == sessionId {
                leaveSession()
            }
        }
    }

    // MARK: - WebSocket Connection

    private func connectToServer(sessionId: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(serverURL)/session/\(sessionId)") else {
            completion(false)
            return
        }

        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        isConnected = true
        startHeartbeat()
        receiveMessages()

        completion(true)
    }

    private func disconnectFromServer() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        stopHeartbeat()
    }

    private func sendMessage(_ message: CollaborationMessage) {
        guard isConnected, let webSocketTask = webSocketTask else { return }

        do {
            let data = try JSONEncoder().encode(message)
            let jsonString = String(data: data, encoding: .utf8) ?? ""
            let message = URLSessionWebSocketTask.Message.string(jsonString)

            webSocketTask.send(message) { error in
                if let error = error {
                    print("[Collaboration] Send error: \(error)")
                }
            }
        } catch {
            print("[Collaboration] Encoding error: \(error)")
        }
    }

    private func receiveMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleReceivedMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleReceivedMessage(text)
                    }
                @unknown default:
                    break
                }

                // Continue receiving
                self.receiveMessages()

            case .failure(let error):
                print("[Collaboration] Receive error: \(error)")
                self.isConnected = false
            }
        }
    }

    private func handleReceivedMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(CollaborationMessage.self, from: data) else {
            return
        }

        DispatchQueue.main.async {
            self.processMessage(message)
        }
    }

    // MARK: - Message Handling

    private func setupMessageHandling() {
        messageSubject
            .sink { [weak self] message in
                self?.processMessage(message)
            }
            .store(in: &cancellables)
    }

    private func processMessage(_ message: CollaborationMessage) {
        guard message.userId != currentUserId else { return }

        switch message.type {
        case .join:
            handleParticipantJoined(message)
        case .leave:
            handleParticipantLeft(message)
        case .annotationAdded:
            handleAnnotationAdded(message)
        case .annotationUpdated:
            handleAnnotationUpdated(message)
        case .annotationDeleted:
            handleAnnotationDeleted(message)
        case .cursorMoved:
            handleCursorMoved(message)
        case .chat:
            handleChatMessage(message)
        case .sync:
            handleSyncRequest(message)
        case .ping:
            handlePing(message)
        case .pong:
            break
        }
    }

    private func handleParticipantJoined(_ message: CollaborationMessage) {
        let participant = CollaborationParticipant(
            id: message.userId,
            username: message.username
        )

        if !participants.contains(where: { $0.id == participant.id }) {
            participants.append(participant)
            addSystemMessage("\(message.username) joined the session")
        }
    }

    private func handleParticipantLeft(_ message: CollaborationMessage) {
        participants.removeAll { $0.id == message.userId }
        addSystemMessage("\(message.username) left the session")
    }

    private func handleAnnotationAdded(_ message: CollaborationMessage) {
        guard let payload = message.payload else { return }

        let annotation = CollaborationAnnotation(
            userId: message.userId,
            username: message.username,
            annotationData: payload
        )

        collaborativeAnnotations.append(annotation)
    }

    private func handleAnnotationUpdated(_ message: CollaborationMessage) {
        guard let payload = message.payload,
              let annotationId = String(data: payload, encoding: .utf8),
              let index = collaborativeAnnotations.firstIndex(where: { $0.id == annotationId }) else {
            return
        }

        collaborativeAnnotations[index].modifiedDate = Date()
    }

    private func handleAnnotationDeleted(_ message: CollaborationMessage) {
        guard let payload = message.payload,
              let annotationId = String(data: payload, encoding: .utf8) else {
            return
        }

        collaborativeAnnotations.removeAll { $0.id == annotationId }
    }

    private func handleCursorMoved(_ message: CollaborationMessage) {
        guard let payload = message.payload,
              let cursorData = try? JSONDecoder().decode(CursorPosition.self, from: payload),
              let index = participants.firstIndex(where: { $0.id == message.userId }) else {
            return
        }

        participants[index].cursorPosition = cursorData.position
    }

    private func handleChatMessage(_ message: CollaborationMessage) {
        guard let payload = message.payload,
              let text = String(data: payload, encoding: .utf8) else {
            return
        }

        let chatMessage = ChatMessage(
            id: message.id,
            userId: message.userId,
            username: message.username,
            text: text,
            timestamp: message.timestamp
        )

        chatMessages.append(chatMessage)
    }

    private func handleSyncRequest(_ message: CollaborationMessage) {
        // Send current state to requesting participant
        syncAnnotations()
    }

    private func handlePing(_ message: CollaborationMessage) {
        let pongMessage = CollaborationMessage(
            sessionId: currentSession?.id ?? "",
            userId: currentUserId,
            username: currentUsername,
            type: .pong
        )
        sendMessage(pongMessage)
    }

    // MARK: - Annotation Sync

    func addAnnotation(_ annotationData: Data) {
        guard let session = currentSession else { return }

        let annotation = CollaborationAnnotation(
            userId: currentUserId,
            username: currentUsername,
            annotationData: annotationData
        )

        collaborativeAnnotations.append(annotation)

        let message = CollaborationMessage(
            sessionId: session.id,
            userId: currentUserId,
            username: currentUsername,
            type: .annotationAdded,
            payload: annotationData
        )

        sendMessage(message)
    }

    func deleteAnnotation(_ annotationId: String) {
        guard let session = currentSession else { return }

        collaborativeAnnotations.removeAll { $0.id == annotationId }

        let payload = annotationId.data(using: .utf8)
        let message = CollaborationMessage(
            sessionId: session.id,
            userId: currentUserId,
            username: currentUsername,
            type: .annotationDeleted,
            payload: payload
        )

        sendMessage(message)
    }

    func syncAnnotations() {
        guard let session = currentSession else { return }

        do {
            let payload = try JSONEncoder().encode(collaborativeAnnotations)
            let message = CollaborationMessage(
                sessionId: session.id,
                userId: currentUserId,
                username: currentUsername,
                type: .sync,
                payload: payload
            )

            sendMessage(message)
        } catch {
            print("[Collaboration] Sync encoding error: \(error)")
        }
    }

    // MARK: - Chat

    func sendChatMessage(_ text: String) {
        guard let session = currentSession else { return }

        let payload = text.data(using: .utf8)
        let message = CollaborationMessage(
            sessionId: session.id,
            userId: currentUserId,
            username: currentUsername,
            type: .chat,
            payload: payload
        )

        sendMessage(message)

        // Add to local chat
        let chatMessage = ChatMessage(
            id: message.id,
            userId: currentUserId,
            username: currentUsername,
            text: text,
            timestamp: Date()
        )
        chatMessages.append(chatMessage)
    }

    private func addSystemMessage(_ text: String) {
        let message = ChatMessage(
            id: UUID().uuidString,
            userId: "system",
            username: "System",
            text: text,
            timestamp: Date()
        )
        chatMessages.append(message)
    }

    // MARK: - Cursor Tracking

    func updateCursorPosition(_ position: CGPoint) {
        guard let session = currentSession else { return }

        let cursorPosition = CursorPosition(position: position)
        guard let payload = try? JSONEncoder().encode(cursorPosition) else { return }

        let message = CollaborationMessage(
            sessionId: session.id,
            userId: currentUserId,
            username: currentUsername,
            type: .cursorMoved,
            payload: payload
        )

        sendMessage(message)
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
    }

    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func sendHeartbeat() {
        guard let session = currentSession else { return }

        let message = CollaborationMessage(
            sessionId: session.id,
            userId: currentUserId,
            username: currentUsername,
            type: .ping
        )

        sendMessage(message)
    }

    // MARK: - Session URL Generation

    func generateShareableURL(for session: CollaborationSession) -> URL? {
        let baseURL = "screengrabber://collaborate"
        guard var components = URLComponents(string: baseURL) else { return nil }

        components.queryItems = [
            URLQueryItem(name: "session", value: session.id),
            URLQueryItem(name: "host", value: session.hostUsername)
        ]

        return components.url
    }
}

// MARK: - Supporting Types

struct CursorPosition: Codable {
    let position: CGPoint
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let userId: String
    let username: String
    let text: String
    let timestamp: Date

    var isSystem: Bool {
        userId == "system"
    }
}

// MARK: - Codable Color
struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(nsColor: NSColor) {
        let color = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        self.red = Double(color.redComponent)
        self.green = Double(color.greenComponent)
        self.blue = Double(color.blueComponent)
        self.alpha = Double(color.alphaComponent)
    }

    var nsColor: NSColor {
        NSColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
    }
}
