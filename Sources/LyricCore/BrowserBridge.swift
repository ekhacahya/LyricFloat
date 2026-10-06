import Foundation
import Network

public final class BrowserBridge {
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "LyricFloat.browser")
    private let token: String
    private let port: NWEndpoint.Port
    public var onSnapshot: ((PlaybackSnapshot) -> [String: Any])?
    public var onStatus: ((String) -> Void)?

    public init(token: String, port: UInt16 = 18473) { self.token = token; self.port = NWEndpoint.Port(rawValue: port)! }
    public func stop() { listener?.cancel(); listener = nil }
    public func start() {
        do {
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(IPv4Address("127.0.0.1")!), port: port)
            let listener = try NWListener(using: parameters)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready: self?.onStatus?("Ready for browser connection")
                    case .failed(let error): self?.onStatus?("Browser connection unavailable: \(error.localizedDescription)")
                    default: break
                    }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: self?.queue ?? .global())
                self?.receive(connection, buffer: Data())
                self?.queue.asyncAfter(deadline: .now() + 5) { connection.cancel() }
            }
            listener.start(queue: queue)
        } catch { onStatus?("Could not start browser connection: \(error.localizedDescription)") }
    }
    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32768) { [weak self] data, _, complete, error in
            guard let self else { connection.cancel(); return }
            var buffer = buffer
            if let data { buffer.append(data) }
            guard buffer.count <= 32768 else { self.reply(connection, status: "413 Payload Too Large", body: [:]); return }
            guard let boundary = buffer.range(of: Data("\r\n\r\n".utf8)) else {
                if complete || error != nil { connection.cancel() } else { self.receive(connection, buffer: buffer) }
                return
            }
            let header = String(decoding: buffer[..<boundary.lowerBound], as: UTF8.self)
            let rows = header.components(separatedBy: "\r\n")
            var headers: [String: String] = [:]
            for row in rows.dropFirst() {
                let parts = row.split(separator: ":", maxSplits: 1)
                if parts.count == 2 { headers[parts[0].lowercased()] = parts[1].trimmingCharacters(in: .whitespaces) }
            }
            guard rows.first == "POST /playback HTTP/1.1", headers["x-lyricfloat-token"] == self.token,
                  let length = Int(headers["content-length"] ?? ""), length >= 0, length <= 24000 else {
                self.reply(connection, status: "403 Forbidden", body: [:]); return
            }
            let body = buffer[boundary.upperBound...]
            guard body.count >= length else {
                if complete || error != nil { connection.cancel() } else { self.receive(connection, buffer: buffer) }
                return
            }
            guard let snapshot = try? JSONDecoder().decode(PlaybackSnapshot.self, from: Data(body.prefix(length))), snapshot.valid else {
                self.reply(connection, status: "400 Bad Request", body: [:]); return
            }
            DispatchQueue.main.async {
                let response = self.onSnapshot?(snapshot) ?? [:]
                self.reply(connection, status: "200 OK", body: response)
            }
        }
    }
    private func reply(_ connection: NWConnection, status: String, body: [String: Any]) {
        let json = (try? JSONSerialization.data(withJSONObject: body)) ?? Data("{}".utf8)
        let header = "HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(json.count)\r\nConnection: close\r\nCache-Control: no-store\r\n\r\n"
        var response = Data(header.utf8); response.append(json)
        connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
    }
}
