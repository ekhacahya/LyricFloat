import XCTest
@testable import LyricCore
final class TrackSessionTests: XCTestCase {
    private func sample(_ id: String, _ title: String, ad: Bool = false) -> PlaybackSnapshot {
        PlaybackSnapshot(id: id, title: title, artist: "Artist", position: 0, duration: 180, playing: true, advertisement: ad)
    }
    func testPlaylistTransitionInvalidatesLyricsAndOldRequests() {
        var session = TrackSession()
        XCTAssertTrue(session.update(sample("a", "First song")))
        let first = session.revision
        XCTAssertTrue(session.update(sample("b", "Second song")))
        XCTAssertNotEqual(first, session.revision)
        let second = session.revision
        XCTAssertFalse(session.update(sample("b", "Second song")))
        XCTAssertEqual(second, session.revision)
    }
    func testMetadataArrivingAfterVideoIDTriggersFreshLookup() {
        var session = TrackSession()
        session.update(sample("a", "First song"))
        session.update(sample("b", "First song"))
        let provisional = session.revision
        XCTAssertTrue(session.update(sample("b", "Second song")))
        XCTAssertNotEqual(provisional, session.revision)
    }
    func testTitleChangeWithUnchangedIDAndAds() {
        var session = TrackSession()
        session.update(sample("a", "First song"))
        XCTAssertFalse(session.update(sample("a", "Advertisement", ad: true)))
        XCTAssertTrue(session.update(sample("a", "Second song")))
        XCTAssertFalse(session.update(sample("a", " SECOND  song ")))
    }
}
