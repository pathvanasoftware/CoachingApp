import Foundation

// MARK: - Connection State

enum WebSocketConnectionState: Sendable {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

// MARK: - WebSocket Service Delegate

protocol WebSocketServiceDelegate: AnyObject, Sendable {
    func webSocketDidConnect()
    func webSocketDidDisconnect(error: Error?)
    func webSocketDidReceiveMessage(_ message: String)
    func webSocketConnectionStateChanged(_ state: WebSocketConnectionState)
}

// MARK: - WebSocket Service

@Observable
final class WebSocketService: NSObject, @unchecked Sendable {

    // MARK: - Properties

    private(set) var connectionState: WebSocketConnectionState = .disconnected
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private let url: URL
    private var pingTimer: Timer?

    weak var delegate: WebSocketServiceDelegate?

    /// Maximum number of automatic reconnection attempts.
    private let maxReconnectAttempts = 5

    /// Current reconnection attempt count.
    private var reconnectAttempt = 0

    /// Base delay in seconds for exponential backoff.
    private let baseReconnectDelay: TimeInterval = 1.0

    /// Whether the service should attempt to reconnect automatically.
    private var shouldReconnect = false

    // MARK: - Init

    init(url: URL) {
        self.url = url
        super.init()
    }

    /// Convenience initializer with a string URL.
    convenience init?(urlString: String) {
        guard let url = URL(string: urlString) else { return nil }
        self.init(url: url)
    }

    deinit {
        disconnect()
    }

    // MARK: - Connection

    /// Open a WebSocket connection.
    func connect() {
        guard connectionState == .disconnected || connectionState == .reconnecting else {
            return
        }

        updateState(.connecting)
        shouldReconnect = true
        reconnectAttempt = 0

        let configuration = URLSessionConfiguration.default
        session = URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: nil
        )

        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()

        startReceiving()
        startPingTimer()
    }

    /// Close the WebSocket connection.
    func disconnect() {
        shouldReconnect = false
        stopPingTimer()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        updateState(.disconnected)
    }

    // MARK: - Sending

    /// Send a text message through the WebSocket.
    func send(text: String) async throws {
        guard connectionState == .connected, let task = webSocketTask else {
            throw WebSocketError.notConnected
        }

        try await task.send(.string(text))
    }

    /// Send JSON-encoded data through the WebSocket.
    func send<T: Encodable>(object: T) async throws {
        let data = try JSONEncoder().encode(object)
        guard let text = String(data: data, encoding: .utf8) else {
            throw WebSocketError.encodingFailed
        }
        try await send(text: text)
    }

    // MARK: - Receiving

    /// Receive the next message asynchronously.
    func receive() async throws -> String {
        guard let task = webSocketTask else {
            throw WebSocketError.notConnected
        }

        let message = try await task.receive()

        switch message {
        case .string(let text):
            return text
        case .data(let data):
            guard let text = String(data: data, encoding: .utf8) else {
                throw WebSocketError.decodingFailed
            }
            return text
        @unknown default:
            throw WebSocketError.unknownMessageType
        }
    }

    /// Returns an AsyncStream that continuously yields received messages.
    func messageStream() -> AsyncStream<String> {
        AsyncStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish()
                    return
                }

                while self.connectionState == .connected {
                    do {
                        let message = try await self.receive()
                        continuation.yield(message)
                    } catch {
                        continuation.finish()
                        break
                    }
                }
            }

            continuation.onTermination = { _ in
                // No-op: connection is managed externally
            }
        }
    }

    // MARK: - Private: Continuous Receive Loop

    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.delegate?.webSocketDidReceiveMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.delegate?.webSocketDidReceiveMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self.startReceiving()

            case .failure(let error):
                self.handleDisconnection(error: error)
            }
        }
    }

    // MARK: - Private: Reconnection

    private func handleDisconnection(error: Error?) {
        stopPingTimer()
        delegate?.webSocketDidDisconnect(error: error)

        guard shouldReconnect, reconnectAttempt < maxReconnectAttempts else {
            updateState(.disconnected)
            return
        }

        updateState(.reconnecting)
        reconnectAttempt += 1

        // Exponential backoff: 1s, 2s, 4s, 8s, 16s
        let delay = baseReconnectDelay * pow(2.0, Double(reconnectAttempt - 1))

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self, self.shouldReconnect else { return }
            self.connect()
        }
    }

    // MARK: - Private: Ping / Keep-Alive

    private func startPingTimer() {
        stopPingTimer()
        DispatchQueue.main.async { [weak self] in
            self?.pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                self?.sendPing()
            }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error {
                self?.handleDisconnection(error: error)
            }
        }
    }

    // MARK: - Private: State

    private func updateState(_ newState: WebSocketConnectionState) {
        connectionState = newState
        delegate?.webSocketConnectionStateChanged(newState)
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketService: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        reconnectAttempt = 0
        updateState(.connected)
        delegate?.webSocketDidConnect()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        handleDisconnection(error: nil)
    }
}

// MARK: - WebSocket Error

enum WebSocketError: Error, LocalizedError {
    case notConnected
    case encodingFailed
    case decodingFailed
    case unknownMessageType
    case connectionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "WebSocket is not connected."
        case .encodingFailed:
            return "Failed to encode the message."
        case .decodingFailed:
            return "Failed to decode the received message."
        case .unknownMessageType:
            return "Received an unknown message type."
        case .connectionFailed(let error):
            return "WebSocket connection failed: \(error.localizedDescription)"
        }
    }
}
