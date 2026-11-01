import XCTest
@testable import WhisProbe

final class WhisProbeTests: XCTestCase {
    func testNameIsOnlyAcceptedAsAnInvocation() {
        XCTAssertNotNil(WakePhrase.match("Whees!"))
        XCTAssertNotNil(WakePhrase.match("Hey, Whis, play something"))
        XCTAssertNil(WakePhrase.match("I think Whis is in Dragon Ball"))
        XCTAssertNil(WakePhrase.match("We should play music"))
        XCTAssertNil(WakePhrase.match("I wish you would play music"))
        XCTAssertNil(WakePhrase.match(""))
        XCTAssertNil(WakePhrase.match("hey"))
    }

    func testSpokenMusicRequestExtractsOnlyTheQuery() {
        let match = WakePhrase.match("Whees, play The Weeknd on YouTube Music")
        XCTAssertEqual(match.flatMap { WakePhrase.musicQuery($0.command) }, "the weeknd")
        XCTAssertNil(WakePhrase.musicQuery("play"))
        XCTAssertNil(WakePhrase.musicQuery("pause"))
        XCTAssertNil(WakePhrase.musicQuery("play on youtube music"))
    }

    func testShortcutInputCannotInjectExtraURLParameters() throws {
        let query = "Beyoncé & friends #1 + chill?"
        let url = try XCTUnwrap(MusicHandoff.shortcutURL(name: "Whis & Music", query: query))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.scheme, "shortcuts")
        XCTAssertEqual(parts.host, "run-shortcut")
        XCTAssertEqual(parts.queryItems?.count, 3)
        XCTAssertEqual(parts.queryItems?.first { $0.name == "text" }?.value, query)
        XCTAssertNil(MusicHandoff.shortcutURL(name: "  ", query: query))
    }

    func testMusicSearchPreservesUnicodeAndQueryBoundaries() throws {
        let query = "AC/DC & café #live"
        let url = try XCTUnwrap(MusicHandoff.searchURL(query: query))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.host, "music.youtube.com")
        XCTAssertEqual(parts.path, "/search")
        XCTAssertEqual(parts.queryItems, [URLQueryItem(name: "q", value: query)])
        XCTAssertNil(parts.fragment)
    }
}
