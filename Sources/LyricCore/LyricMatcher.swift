import Foundation

public enum LyricMatcher {
    private static func normalize(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public static let maximumDurationDifference = 5.0

    /// Keep timed lyrics first, then put the nearest duration at the top of each group.
    public static func orderedByDuration(_ records: [LyricRecord], duration: Double) -> [LyricRecord] {
        func difference(_ record: LyricRecord) -> Double {
            guard duration.isFinite, duration > 0, let length = record.duration, length.isFinite, length > 0 else { return .infinity }
            return abs(length - duration)
        }
        return records.sorted { first, second in
            let firstTimed = !(first.syncedLyrics ?? "").isEmpty
            let secondTimed = !(second.syncedLyrics ?? "").isEmpty
            if firstTimed != secondTimed { return firstTimed }
            let firstDifference = difference(first), secondDifference = difference(second)
            return firstDifference == secondDifference ? first.id < second.id : firstDifference < secondDifference
        }
    }

    /// Auto-select only matching timed lyrics within five seconds of actual playback duration.
    public static func bestMatch(in records: [LyricRecord], title: String, artist: String, duration: Double) -> LyricRecord? {
        guard duration.isFinite, duration > 0 else { return nil }
        let title = normalize(title), artist = normalize(artist)
        return orderedByDuration(records, duration: duration).first { record in
            guard let synced = record.syncedLyrics, !LRC.parse(synced).isEmpty,
                  let length = record.duration, length.isFinite, length > 0, abs(length - duration) <= maximumDurationDifference else { return false }
            let song = normalize(record.trackName), performer = normalize(record.artistName)
            guard !song.isEmpty, !performer.isEmpty else { return false }
            let containsSong = (" " + title + " ").contains(" " + song + " ")
            let containsArtist = (" " + title + " ").contains(" " + performer + " ") || artist == performer
            return title == song || (containsSong && containsArtist)
        }
    }
}
