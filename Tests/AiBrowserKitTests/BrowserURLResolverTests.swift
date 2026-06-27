import Foundation
import Testing
@testable import AiBrowserKit

@Suite("BrowserURLResolver")
struct BrowserURLResolverTests {

    @Test("Empty and whitespace input returns nil")
    func emptyInput() {
        #expect(BrowserURLResolver.resolve(input: "") == nil)
        #expect(BrowserURLResolver.resolve(input: "   ") == nil)
    }

    @Test("Absolute https URL passes through")
    func httpsURL() {
        let url = BrowserURLResolver.resolve(input: "https://example.com/path")
        #expect(url?.absoluteString == "https://example.com/path")
    }

    @Test("Absolute http URL passes through")
    func httpURL() {
        let url = BrowserURLResolver.resolve(input: "http://example.com")
        #expect(url?.scheme == "http")
        #expect(url?.host() == "example.com")
    }

    @Test("Custom aibrowser scheme passes through")
    func customScheme() {
        let url = BrowserURLResolver.resolve(input: "aibrowser://panel/home")
        #expect(url?.scheme == "aibrowser")
    }

    @Test("localhost gets http prefix")
    func localhost() {
        let url = BrowserURLResolver.resolve(input: "localhost:8080/docs")
        #expect(url?.scheme == "http")
        #expect(url?.host() == "localhost")
        #expect(url?.port == 8080)
    }

    @Test("127.0.0.1 gets http prefix")
    func loopback() {
        let url = BrowserURLResolver.resolve(input: "127.0.0.1:3000")
        #expect(url?.scheme == "http")
        #expect(url?.host() == "127.0.0.1")
    }

    @Test("Bare domain gets https prefix")
    func bareDomain() {
        let url = BrowserURLResolver.resolve(input: "apple.com")
        #expect(url?.scheme == "https")
        #expect(url?.host() == "apple.com")
    }

    @Test("Search query falls back to Google")
    func searchFallback() {
        let url = BrowserURLResolver.resolve(input: "swift concurrency")
        #expect(url?.host()?.contains("google.com") == true)
        #expect(url?.absoluteString.contains("search?q=") == true)
    }

    @Test("Leading/trailing whitespace is trimmed")
    func trimsWhitespace() {
        let url = BrowserURLResolver.resolve(input: "  https://example.com  ")
        #expect(url?.host() == "example.com")
    }
}
