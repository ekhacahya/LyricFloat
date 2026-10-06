import XCTest
import Foundation
@testable import LyricCore

final class BrowserBridgeTests: XCTestCase {
    func testLoopbackAuthenticationAndPlaybackDelivery() {
        let ready = expectation(description: "Listener ready")
        let delivery = expectation(description: "Playback delivered")
        let validResponse = expectation(description: "Authenticated response")
        let rejected = expectation(description: "Invalid code rejected")
        let invalid = expectation(description: "Invalid JSON rejected")
        let bridge = BrowserBridge(token: "integration-test", port: 18474)
        bridge.onStatus = { status in
            if status.hasPrefix("Ready") { ready.fulfill() }
            else { XCTFail(status) }
        }
        bridge.onSnapshot = { sample in
            XCTAssertEqual(sample.position, 12.5)
            XCTAssertEqual(sample.id, "test")
            delivery.fulfill()
            return ["command": ["type": "seek", "position": 20]]
        }
        bridge.start()
        defer { bridge.stop() }
        wait(for: [ready], timeout: 5)
        let sample = PlaybackSnapshot(id: "test", title: "Original test", artist: "Test", position: 12.5, duration: 42, playing: false)
        let body = try! JSONEncoder().encode(sample)
        func request(_ token: String, body: Data, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:18474/playback")!)
            request.httpMethod = "POST"; request.httpBody = body
            request.setValue(token, forHTTPHeaderField: "X-LyricFloat-Token")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            URLSession.shared.dataTask(with: request, completionHandler: completion).resume()
        }
        request("wrong", body: body) { _, response, error in
            XCTAssertNil(error); XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 403); rejected.fulfill()
        }
        request("integration-test", body: Data("{}".utf8)) { _, response, error in
            XCTAssertNil(error); XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 400); invalid.fulfill()
        }
        request("integration-test", body: body) { data, response, error in
            XCTAssertNil(error); XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            if let data, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let command = object["command"] as? [String: Any] {
                XCTAssertEqual(command["position"] as? Int, 20)
            } else { XCTFail("Missing command") }
            validResponse.fulfill()
        }
        wait(for: [delivery, validResponse, rejected, invalid], timeout: 5)
    }
}
