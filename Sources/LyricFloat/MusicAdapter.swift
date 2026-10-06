import Foundation
import LyricCore

final class MusicAdapter {
    private let queue = DispatchQueue(label: "LyricFloat.music")
    private var busy = false
    func poll(source: Source, completion: @escaping (PlaybackSnapshot?, String?) -> Void) {
        guard !busy else { return }; busy = true
        let name = source == .appleMusic ? "Music" : "Spotify"
        let duration = source == .appleMusic ? "duration of current track" : "(duration of current track) / 1000"
        let script = """
        if application "\(name)" is running then
            tell application "\(name)"
                if player state is stopped then return "STOPPED"
                set t to current track
                set fields to {(id of t as text), (name of t as text), (artist of t as text), (player position as text), (\(duration) as text), (player state as text)}
                set AppleScript's text item delimiters to ASCII character 31
                return fields as text
            end tell
        else
            return "NOT_RUNNING"
        end if
        """
        run(script) { [weak self] output, error in
            self?.busy = false
            guard let output, output != "NOT_RUNNING", output != "STOPPED" else {
                completion(nil, error ?? "Open \(name) and play a song"); return
            }
            let fields = output.components(separatedBy: "\u{1f}")
            guard fields.count == 6, let position = Double(fields[3]), let length = Double(fields[4]) else { completion(nil, "Could not read \(name) playback"); return }
            completion(PlaybackSnapshot(id: "\(name):\(fields[0])", title: fields[1], artist: fields[2], position: position, duration: length, playing: fields[5] == "playing"), nil)
        }
    }
    func command(source: Source, position: Double? = nil, completion: @escaping (String?) -> Void) {
        let name = source == .appleMusic ? "Music" : "Spotify"
        let operation = position.map { "set player position to \(max(0, $0))" } ?? "playpause"
        run("tell application \"\(name)\" to \(operation)") { _, error in completion(error) }
    }
    private func run(_ script: String, completion: @escaping (String?, String?) -> Void) {
        queue.async {
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript"); process.arguments = ["-e", script]
            let output = Pipe(), errors = Pipe(); process.standardOutput = output; process.standardError = errors
            do {
                try process.run()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                let errorData = errors.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                let detail = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                DispatchQueue.main.async { completion(process.terminationStatus == 0 ? text : nil, process.terminationStatus == 0 ? nil : detail) }
            } catch { DispatchQueue.main.async { completion(nil, error.localizedDescription) } }
        }
    }
}
