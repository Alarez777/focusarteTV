import XCTest
@testable import FocusarteCore

final class WistiaTests: XCTestCase {
    func testParsesHLSAndFallback() throws {
        let json = """
        {
          "media": {
            "duration": 545.4,
            "hls_enabled": true,
            "assets": [
              {"type": "original", "url": "https://embed-ssl.wistia.com/original.bin", "width": 1920},
              {"type": "hd_mp4_video", "url": "https://embed-ssl.wistia.com/720.bin", "width": 1280},
              {"type": "hd_mp4_video", "url": "https://embed-ssl.wistia.com/1080.bin", "width": 1920},
              {"type": "still_image", "url": "https://embed-ssl.wistia.com/still.jpg"}
            ]
          }
        }
        """.data(using: .utf8)!

        let asset = try Wistia.parseMedia(json: json, mediaID: "03929lqadx")

        XCTAssertEqual(
            asset.hlsURL?.absoluteString,
            "https://fast.wistia.com/embed/medias/03929lqadx.m3u8"
        )
        XCTAssertEqual(asset.posterURL?.absoluteString, "https://embed-ssl.wistia.com/still.jpg")
        XCTAssertEqual(asset.mp4Fallback?.absoluteString, "https://embed-ssl.wistia.com/1080.bin")
        XCTAssertEqual(asset.duration, 545.4, accuracy: 0.01)
    }

    func testDisablesHLSWhenFlagIsFalse() throws {
        let json = """
        {"media": {"duration": 10, "hls_enabled": false, "assets": [
          {"type": "md_mp4_video", "url": "https://embed-ssl.wistia.com/540.bin", "width": 960}
        ]}}
        """.data(using: .utf8)!

        let asset = try Wistia.parseMedia(json: json, mediaID: "abc")
        XCTAssertNil(asset.hlsURL)
        XCTAssertEqual(asset.playbackURL?.absoluteString, "https://embed-ssl.wistia.com/540.bin")
    }
}
