import Foundation

/// YouTube changes its URL, metadata, and media element at different times.
/// A metadata change must invalidate lyrics even when the reported video ID is unchanged.
public struct TrackSession {
    public private(set) var identity = ""
    public private(set) var revision = UUID()
    public init() {}
    @discardableResult public mutating func update(_ sample: PlaybackSnapshot) -> Bool {
        guard sample.valid, !sample.advertisement else { return false }
        let title = Self.normalize(sample.title)
        let artist = Self.normalize(sample.artist)
        let next = "\(sample.id)\u{1f}\(title)\u{1f}\(artist)"
        guard identity != next else { return false }
        identity = next; revision = UUID()
        return true
    }
    public mutating func reset() { identity = ""; revision = UUID() }
    private static func normalize(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").lowercased()
    }
}
