import XCTest
@testable import NekoCore
@testable import NekoServices
@testable import NekoUI

final class NekoKitTests: XCTestCase {
    func testSafeURLBuildsCleanly() {
        let url = SafeURL.make(
            host: "translate.googleapis.com",
            path: "/translate_a/single",
            queryItems: [URLQueryItem(name: "q", value: "hello world")]
        )
        XCTAssertNotNil(url)
        XCTAssertTrue(url?.absoluteString.contains("q=hello%20world") == true)
    }

    func testIPANormalizerFormatsStandardIPA() {
        XCTAssertEqual(IPANormalizer.normalize("/'dɪkʃə,nɛɹi/"), "/ˈdɪkʃəˌnɛri/")
    }

    func testWordLookupModeDefaults() {
        XCTAssertEqual(WordLookupMode.allCases.count, 2)
        XCTAssertEqual(WordLookupMode.dictionary.shortTitle, "Từ điển")
        XCTAssertEqual(WordLookupMode.quickTranslate.shortTitle, "Dịch gọn")
    }
}
