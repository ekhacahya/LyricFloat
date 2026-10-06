import XCTest
@testable import LyricCore
final class LyricMatcherTests: XCTestCase {
    private func record(_ id: Int, title: String = "Song", artist: String = "Artist", duration: Double, timed: Bool = true) -> LyricRecord {
        LyricRecord(id: id, trackName: title, artistName: artist, albumName: nil, duration: duration, instrumental: false, plainLyrics: nil, syncedLyrics: timed ? "[00:01]Original test line" : nil)
    }
    func testSmallDurationDifferenceAndPunctuationStillMatch() {
        let match = LyricMatcher.bestMatch(in: [record(1, duration: 180)], title: "Artist: Song", artist: "Music channel", duration: 183)
        XCTAssertEqual(match?.id, 1)
    }
    func testLargeIntroIsNotAutomaticallyMatched() {
        XCTAssertNil(LyricMatcher.bestMatch(in: [record(1, duration: 180)], title: "Artist: Song", artist: "Artist", duration: 195))
    }
    func testExactDurationWinsOverNearMatch() {
        let records = [record(1, duration: 183), record(2, duration: 180)]
        XCTAssertEqual(LyricMatcher.bestMatch(in: records, title: "Song", artist: "Artist", duration: 180)?.id, 2)
    }
    func testResultsAreTimedThenNearestDuration() {
        let records = [record(1, duration: 210), record(2, duration: 181), record(3, duration: 180, timed: false), record(4, duration: 180)]
        XCTAssertEqual(LyricMatcher.orderedByDuration(records, duration: 180).map(\.id), [4, 2, 1, 3])
    }
    func testUnknownPlaybackDurationDoesNotAutoSelect() {
        XCTAssertNil(LyricMatcher.bestMatch(in: [record(1, duration: 180)], title: "Song", artist: "Artist", duration: 0))
    }
    func testClosestVersionWins() {
        let records = [record(1, duration: 180), record(2, duration: 196)]
        XCTAssertEqual(LyricMatcher.bestMatch(in: records, title: "Song", artist: "Artist", duration: 195)?.id, 2)
    }
    func testWrongSongUntimedAndLongLiveVersionAreRejected() {
        let records = [record(1, title: "Other song", duration: 180), record(2, duration: 180, timed: false), record(3, duration: 300)]
        XCTAssertNil(LyricMatcher.bestMatch(in: records, title: "Artist - Song", artist: "Artist", duration: 180))
    }
}
