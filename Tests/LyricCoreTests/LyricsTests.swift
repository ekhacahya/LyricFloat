import XCTest
@testable import LyricCore
final class LyricsTests: XCTestCase {
    func testFractionsMultipleTagsAndOffset() {
        let lines = LRC.parse("[ar:Artist]\n[offset:-500]\n[00:04.12][00:08.123] chorus\n[00:01.5]first\n[00:70]bad\n[00:09.00]")
        XCTAssertEqual(lines.count, 4)
        XCTAssertEqual(lines[0].time, 1, accuracy: 0.001)
        XCTAssertEqual(lines[1].time, 3.62, accuracy: 0.001)
        XCTAssertEqual(lines[2].time, 7.623, accuracy: 0.001)
        XCTAssertEqual(lines[3].text, "")
    }
    func testCurrentLineAtBoundariesAndSeek() {
        let lines = LRC.parse("[00:02]one\n[00:05]two\n[00:05]three")
        XCTAssertNil(LRC.currentIndex(in: lines, at: 1.99))
        XCTAssertEqual(LRC.currentIndex(in: lines, at: 2), 0)
        XCTAssertEqual(LRC.currentIndex(in: lines, at: 5), 2)
        XCTAssertEqual(LRC.currentIndex(in: lines, at: 3), 0)
        XCTAssertNil(LRC.currentIndex(in: [], at: 20))
    }
    func testClockRespectsPauseAdsRateAndStaleLimit() {
        var sample = PlaybackSnapshot(id: "x", title: "song", artist: "artist", position: 10, duration: 30, playing: true, rate: 2)
        XCTAssertEqual(sample.estimatedPosition(elapsed: 1), 12)
        XCTAssertEqual(sample.estimatedPosition(elapsed: 100), 16)
        sample.playing = false
        XCTAssertEqual(sample.estimatedPosition(elapsed: 1), 10)
        sample.playing = true; sample.advertisement = true
        XCTAssertEqual(sample.estimatedPosition(elapsed: 1), 10)
        sample.position = .nan
        XCTAssertFalse(sample.valid)
    }
}
