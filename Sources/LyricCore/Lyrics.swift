import Foundation

public struct LyricLine: Identifiable, Equatable {
    public let id: Int
    public let time: Double
    public let text: String
    public init(id: Int, time: Double, text: String) { self.id = id; self.time = time; self.text = text }
}

public enum LRC {
    public static func parse(_ input: String) -> [LyricLine] {
        let pattern = try! NSRegularExpression(pattern: #"\[(\d+):(\d{2})(?:[.:](\d{1,3}))?\]"#)
        let offsetPattern = try! NSRegularExpression(pattern: #"\[offset:([+-]?\d+)\]"#, options: .caseInsensitive)
        let ns = input as NSString
        var offset = 0.0
        if let match = offsetPattern.firstMatch(in: input, range: NSRange(location: 0, length: ns.length)) {
            offset = (Double(ns.substring(with: match.range(at: 1))) ?? 0) / 1000
        }
        var entries: [(Double, String)] = []
        for raw in input.components(separatedBy: .newlines) {
            let line = raw as NSString
            let matches = pattern.matches(in: raw, range: NSRange(location: 0, length: line.length))
            guard let last = matches.last else { continue }
            let text = line.substring(from: NSMaxRange(last.range)).trimmingCharacters(in: .whitespaces)
            for match in matches {
                let minutes = Double(line.substring(with: match.range(at: 1))) ?? 0
                let seconds = Double(line.substring(with: match.range(at: 2))) ?? 0
                guard seconds < 60 else { continue }
                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound {
                    let digits = line.substring(with: match.range(at: 3))
                    fraction = (Double(digits) ?? 0) / pow(10, Double(digits.count))
                }
                entries.append((max(0, minutes * 60 + seconds + fraction + offset), text))
            }
        }
        return entries.enumerated().sorted { a, b in a.element.0 == b.element.0 ? a.offset < b.offset : a.element.0 < b.element.0 }.enumerated().map { index, entry in LyricLine(id: index, time: entry.element.0, text: entry.element.1) }
    }

    public static func currentIndex(in lines: [LyricLine], at time: Double) -> Int? {
        var low = 0, high = lines.count
        while low < high {
            let middle = (low + high) / 2
            if lines[middle].time <= time { low = middle + 1 } else { high = middle }
        }
        return low == 0 ? nil : low - 1
    }
}

public struct PlaybackSnapshot: Codable {
    public var id: String
    public var title: String
    public var artist: String
    public var position: Double
    public var duration: Double
    public var playing: Bool
    public var rate: Double
    public var advertisement: Bool
    public init(id: String, title: String, artist: String, position: Double, duration: Double, playing: Bool, rate: Double = 1, advertisement: Bool = false) {
        self.id = id; self.title = title; self.artist = artist; self.position = position; self.duration = duration; self.playing = playing; self.rate = rate; self.advertisement = advertisement
    }
    public var valid: Bool { !id.isEmpty && position.isFinite && position >= 0 && duration.isFinite && duration >= 0 && rate.isFinite && rate > 0 && rate <= 16 }
    public func estimatedPosition(elapsed: Double) -> Double {
        let value = position + (playing && !advertisement ? max(0, min(elapsed, 3)) * rate : 0)
        return duration > 0 ? min(value, duration) : value
    }
}

public struct LyricRecord: Codable, Identifiable {
    public let id: Int
    public let trackName: String
    public let artistName: String
    public let albumName: String?
    public let duration: Double?
    public let instrumental: Bool?
    public let plainLyrics: String?
    public let syncedLyrics: String?
}
