import XCTest
@testable import TheQuestOfferwall

final class LaunchURLBuilderTests: XCTestCase {

    private let base = URL(string: "https://quest.humanlabs.world")!

    // MARK: Standard mode

    func testStandardModeHasNoSignatureParams() throws {
        let url = try XCTUnwrap(LaunchURLBuilder.build(
            baseURL: base,
            appId: "ABCDE12345",
            userId: "user-1",
            token: nil,
            deviceLanguageCode: "en-US"
        ))
        let items = queryItems(url)
        XCTAssertEqual(items["app_id"], "ABCDE12345")
        XCTAssertEqual(items["user_id"], "user-1")
        XCTAssertEqual(items["locale"], "en")
        XCTAssertNil(items["ts"])
        XCTAssertNil(items["nonce"])
        XCTAssertNil(items["sig"])
        XCTAssertEqual(url.host, "quest.humanlabs.world")
        XCTAssertEqual(url.path, "/")
    }

    // MARK: Secure mode

    func testSecureModeIncludesSignatureParams() throws {
        let token = LaunchToken(ts: "1720000000000", nonce: "abc123nonce", sig: "deadbeef", locale: "id")
        let url = try XCTUnwrap(LaunchURLBuilder.build(
            baseURL: base,
            appId: "ABCDE12345",
            userId: "user-42",
            token: token,
            deviceLanguageCode: "en-US"
        ))
        let items = queryItems(url)
        XCTAssertEqual(items["app_id"], "ABCDE12345")
        XCTAssertEqual(items["user_id"], "user-42")
        XCTAssertEqual(items["ts"], "1720000000000")
        XCTAssertEqual(items["nonce"], "abc123nonce")
        XCTAssertEqual(items["sig"], "deadbeef")
        // Signed locale overrides the device locale so the signature stays valid.
        XCTAssertEqual(items["locale"], "id")
    }

    func testSecureModeWithNilLocaleSendsEmptyLocale() throws {
        let token = LaunchToken(ts: "1720000000", nonce: "n", sig: "s", locale: nil)
        let url = try XCTUnwrap(LaunchURLBuilder.build(
            baseURL: base,
            appId: "ABCDE12345",
            userId: "u",
            token: token,
            deviceLanguageCode: "pt-BR"
        ))
        // Empty (matches backend canonical message locale ""), but still present.
        XCTAssertTrue(url.query?.contains("locale=") == true)
        XCTAssertEqual(queryItems(url)["locale"], "")
    }

    // MARK: Locale mapping

    func testLocaleMappingSupportedAndFallback() {
        XCTAssertEqual(LaunchURLBuilder.normalizedLocale(from: "en"), "en")
        XCTAssertEqual(LaunchURLBuilder.normalizedLocale(from: "ID"), "id")
        XCTAssertEqual(LaunchURLBuilder.normalizedLocale(from: "es-ES"), "es")
        XCTAssertEqual(LaunchURLBuilder.normalizedLocale(from: "pt_BR"), "pt")
        XCTAssertEqual(LaunchURLBuilder.normalizedLocale(from: "fr-FR"), "en")
        XCTAssertEqual(LaunchURLBuilder.normalizedLocale(from: nil), "en")
        XCTAssertEqual(LaunchURLBuilder.normalizedLocale(from: ""), "en")
    }

    func testStandardModeMapsUnsupportedDeviceLocaleToFallback() throws {
        let url = try XCTUnwrap(LaunchURLBuilder.build(
            baseURL: base,
            appId: "ABCDE12345",
            userId: "u",
            token: nil,
            deviceLanguageCode: "de-DE"
        ))
        XCTAssertEqual(queryItems(url)["locale"], "en")
    }

    // MARK: Encoding

    func testValuesArePercentEncoded() throws {
        let url = try XCTUnwrap(LaunchURLBuilder.build(
            baseURL: base,
            appId: "ABCDE12345",
            userId: "a b&c=d+e",
            token: nil,
            deviceLanguageCode: "en"
        ))
        // The raw query must escape space, &, =, and +.
        let rawQuery = try XCTUnwrap(url.query)
        XCTAssertTrue(rawQuery.contains("user_id=a%20b%26c%3Dd%2Be"))
        // Decoded round-trip is intact.
        XCTAssertEqual(queryItems(url)["user_id"], "a b&c=d+e")
    }

    func testStagingBaseURL() throws {
        let staging = URL(string: "https://quest.seriesc.dev")!
        let url = try XCTUnwrap(LaunchURLBuilder.build(
            baseURL: staging,
            appId: "ABCDE12345",
            userId: "u",
            token: nil,
            deviceLanguageCode: "en"
        ))
        XCTAssertEqual(url.host, "quest.seriesc.dev")
    }

    // MARK: Helpers

    /// Decodes query items using percent-decoding (URLComponents un-escapes values).
    private func queryItems(_ url: URL) -> [String: String] {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var result: [String: String] = [:]
        for item in comps?.queryItems ?? [] {
            result[item.name] = item.value ?? ""
        }
        return result
    }
}
