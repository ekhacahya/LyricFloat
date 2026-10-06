import AppKit
import AVFoundation
import Combine
import LyricCore
import UniformTypeIdentifiers

 enum Source: String, CaseIterable, Identifiable {
    case youtube = "YouTube", appleMusic = "Apple Music", spotify = "Spotify", local = "Local audio", demo = "Demo"
    var id: String { rawValue }
    var symbol: String {
        switch self { case .youtube: return "play.rectangle.fill"; case .appleMusic: return "music.note"; case .spotify: return "waveform.circle.fill"; case .local: return "folder.fill"; case .demo: return "sparkles" }
    }
 }

final class PlayerModel: ObservableObject {
    @Published var isCompact = false
    @Published var lyricRevision = UUID()
    @Published var source: Source = .youtube { didSet { if source != oldValue { changeSource() } } }
    @Published var title = "Your next sing-along"
    @Published var artist = "Connect YouTube to get started"
    @Published var position = 0.0
    @Published var duration = 0.0
    @Published var playing = false
    @Published var connected = false
    @Published var advertisement = false
    @Published var lines: [LyricLine] = []
    @Published var plainLyrics: String?
    @Published var lyricCredit = ""
    @Published var status = "Waiting for YouTube"
    @Published var bridgeStatus = "Starting browser connection…"
    @Published var offset = 0.0
    @Published var fontSize = 26.0
    @Published var pinned = true
    @Published var showSetup = false
    @Published var showSearch = false
    @Published var query = ""
    @Published var results: [LyricRecord] = []
    @Published var searching = false
    @Published var searchMessage = "Search by song title and artist"
    @Published var errorMessage: String?
    let token: String
    private var bridge: BrowserBridge!
    private var timer: Timer?
    private var snapshot: PlaybackSnapshot?
    private var receivedAt = Date.distantPast
    private var nextPoll = Date.distantPast
    private let adapter = MusicAdapter()
    private var audio: AVAudioPlayer?
    private var pendingCommand: [String: Any]?
    private var searchTask: Task<Void, Never>?
    private var trackID = ""
    private var trackSession = TrackSession()
    private var demoStart = Date()
    private var demoPosition = 0.0
    var currentIndex: Int? { advertisement ? nil : LRC.currentIndex(in: lines, at: position - offset) }
    var lyricTime: Double { max(0, position - offset) }

    init() {
        let defaults = UserDefaults.standard
        token = defaults.string(forKey: "browserToken") ?? UUID().uuidString
        defaults.set(token, forKey: "browserToken")
        bridge = BrowserBridge(token: token)
        bridge.onStatus = { [weak self] in self?.bridgeStatus = $0 }
        bridge.onSnapshot = { [weak self] sample in
            guard let self, self.source == .youtube else { return [:] }
            self.accept(sample)
            if let command = self.pendingCommand { self.pendingCommand = nil; return ["command": command] }
            return [:]
        }
        bridge.start()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
    }
    private func changeSource() {
        audio?.pause(); pendingCommand = nil; snapshot = nil; trackID = ""; trackSession.reset(); lyricRevision = UUID(); receivedAt = .distantPast
        searchTask?.cancel(); searching = false; results = []; lines = []; plainLyrics = nil; lyricCredit = ""; offset = 0
        position = 0; duration = 0; playing = false; connected = false; advertisement = false
        title = "Your next sing-along"; artist = source == .youtube ? "Connect YouTube to get started" : "Choose a song in \(source.rawValue)"
        status = "Waiting for \(source.rawValue)"
        if source == .demo { loadDemo() }
        if source == .local { title = "Bring your own music"; artist = "Open audio, then import matching LRC lyrics" }
    }
    private func tick() {
        switch source {
        case .local:
            if let audio { position = audio.currentTime; playing = audio.isPlaying; connected = true }
        case .demo:
            if playing { position = min(duration, demoPosition + Date().timeIntervalSince(demoStart)); if position >= duration { playing = false } }
        default:
            let elapsed = Date().timeIntervalSince(receivedAt)
            let fresh = elapsed < (source == .youtube ? 3 : 6)
            connected = snapshot != nil && fresh
            playing = fresh && (snapshot?.playing ?? false) && !advertisement
            if let snapshot, fresh { position = snapshot.estimatedPosition(elapsed: elapsed) }
            if !fresh { status = source == .youtube ? "Waiting for browser · open a YouTube video" : "Waiting for \(source.rawValue)" }
            if source != .youtube && Date() >= nextPoll {
                nextPoll = Date().addingTimeInterval(1)
                let requestedSource = source
                adapter.poll(source: requestedSource) { [weak self] sample, error in
                    guard let self, self.source == requestedSource else { return }
                    if let sample { self.accept(sample) } else { self.snapshot = nil; self.connected = false; self.playing = false; self.status = error ?? "Waiting for playback" }
                }
            }
        }
    }
    private func accept(_ sample: PlaybackSnapshot) {
        guard sample.valid else { return }
        snapshot = sample; receivedAt = Date(); connected = true
        position = sample.position; duration = sample.duration; playing = sample.playing && !sample.advertisement; advertisement = sample.advertisement
        status = sample.advertisement ? "Advertisement · lyrics paused" : (sample.playing ? "Following playback" : "Playback paused")
        if sample.advertisement { return }
        if trackSession.update(sample) {
            searchTask?.cancel(); searching = false; results = []
            lyricRevision = trackSession.revision
            trackID = sample.id; title = sample.title; artist = sample.artist
            lines = []; plainLyrics = nil; offset = 0; lyricCredit = ""; pendingCommand = nil
            query = cleanTitle(sample.title)
            if source != .youtube { query += " \(sample.artist)" }
            search(automatic: true)
        } else if !sample.advertisement { title = sample.title; artist = sample.artist }
    }
    private func cleanTitle(_ title: String) -> String {
        title.replacingOccurrences(of: #"(?i)[\[(][^\])]*(official|video|audio|lyrics?|visualizer|4k|hd)[^\])]*[\])]"#, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    func togglePlayback() {
        guard connected else { return }
        switch source {
        case .youtube: pendingCommand = ["type": "toggle"]
        case .local: if let audio { if audio.isPlaying { audio.pause() } else { audio.play() }; playing = audio.isPlaying }
        case .demo:
            demoPosition = position; demoStart = Date(); playing.toggle()
        case .appleMusic, .spotify: adapter.command(source: source) { [weak self] error in if let error { self?.errorMessage = error } }
        }
    }
    func seek(_ value: Double) {
        guard connected, !advertisement else { return }
        let value = max(0, min(duration, value))
        switch source {
        case .youtube: pendingCommand = ["type": "seek", "position": value]
        case .local: audio?.currentTime = value; position = value
        case .demo: position = value; demoPosition = value; demoStart = Date()
        case .appleMusic, .spotify: adapter.command(source: source, position: value) { [weak self] error in if let error { self?.errorMessage = error } }
        }
    }
    func search(automatic: Bool = false) {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        searching = true; results = []; searchMessage = "Finding lyrics…"
        let requestedRevision = lyricRevision
        searchTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                var components = URLComponents(string: "https://lrclib.net/api/search")!
                components.queryItems = [URLQueryItem(name: "q", value: text)]
                var request = URLRequest(url: components.url!); request.timeoutInterval = 20
                request.setValue("LyricFloat/1.0 (macOS personal lyrics player)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let response = response as? HTTPURLResponse, response.statusCode == 200 else { throw URLError(.badServerResponse) }
                let records = try JSONDecoder().decode([LyricRecord].self, from: data)
                try Task.checkCancellation()
                do {
                    guard self.lyricRevision == requestedRevision else { return }
                    self.searching = false
                    self.results = LyricMatcher.orderedByDuration(records, duration: self.duration)
                    self.searchMessage = records.isEmpty ? "No lyrics found. Try a shorter title or import an LRC file." : "Choose the version that matches your song"
                    if automatic {
                        if let match = LyricMatcher.bestMatch(in: self.results, title: self.cleanTitle(self.title), artist: self.artist, duration: self.duration) {
                            self.use(match)
                        } else if !records.isEmpty {
                            self.searchMessage = "No matching timed lyrics within 5 seconds of this video. Choose a version manually."
                        }
                    }
                }
            } catch {
                if Task.isCancelled { return }
                do {
                    guard self.lyricRevision == requestedRevision else { return }
                    self.searching = false; self.searchMessage = "Lyrics search unavailable. Check your connection or import an LRC file."
                }
            }
        }
    }
    func use(_ record: LyricRecord) {
        searchTask?.cancel(); searching = false
        lyricRevision = UUID()
        lines = LRC.parse(record.syncedLyrics ?? "")
        plainLyrics = lines.isEmpty ? record.plainLyrics : nil
        lyricCredit = "\(record.trackName) · \(record.artistName) · LRCLIB"
        if record.instrumental == true { lyricCredit = "Instrumental · no sung lyrics" }
        offset = 0; showSearch = false
    }
    func importLyrics() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.plainText, UTType(filenameExtension: "lrc") ?? .plainText]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try loadLyrics(url) } catch { errorMessage = error.localizedDescription }
    }
    private func loadLyrics(_ url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        let parsed = LRC.parse(text)
        guard !parsed.isEmpty else { throw NSError(domain: "LyricFloat", code: 1, userInfo: [NSLocalizedDescriptionKey: "This file has no timestamped lyrics. Use LRC lines such as [00:12.50] Your lyric."]) }
        searchTask?.cancel(); searching = false; lyricRevision = UUID(); lines = parsed; plainLyrics = nil; lyricCredit = url.lastPathComponent; offset = 0
    }
    func openAudio() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.audio]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url); player.prepareToPlay()
            if source == .local { changeSource() } else { source = .local }
            audio = player; title = url.deletingPathExtension().lastPathComponent; artist = "Local audio"; duration = player.duration; position = 0; connected = true
            trackID = url.path; query = title; status = "Local audio ready"
            let sibling = url.deletingPathExtension().appendingPathExtension("lrc")
            if FileManager.default.fileExists(atPath: sibling.path) { try loadLyrics(sibling) }
            player.play(); playing = true
        } catch { errorMessage = "Could not open this audio file: \(error.localizedDescription)" }
    }
    private func loadDemo() {
        title = "A little room to sing"; artist = "LyricFloat · silent timing demo"
        duration = 42; connected = true; playing = true; status = "Demo · no audio"; demoPosition = 0; demoStart = Date()
        lines = LRC.parse("[00:00]Take a breath, let the day slow down\n[00:06]Find your voice in a quiet sound\n[00:12]Let the words float into the light\n[00:18]Sing a little louder tonight\n[00:24]Every line has a place to start\n[00:30]Keep the rhythm close to your heart\n[00:36]Take a breath, let the day slow down")
        lyricCredit = "Original demo lyrics"
    }
    func revealExtension() {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("BrowserExtension")
        let development = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("BrowserExtension")
        let url = bundled.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil } ?? development
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    func copyToken() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(token, forType: .string) }
    static func time(_ seconds: Double) -> String { let value = Int(max(0, min(359999, seconds.isFinite ? seconds : 0))); return String(format: "%d:%02d", value / 60, value % 60) }
}
