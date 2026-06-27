import Foundation

/// Pure URL-bar resolution used by `BrowserTab.navigate(to:)`.
public enum BrowserURLResolver {

    /// Resolves user input from the URL bar into a loadable URL.
    /// Returns `nil` for empty/whitespace-only input.
    public static func resolve(input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("aibrowser://") {
            return URL(string: trimmed)
        }

        if trimmed.hasPrefix("localhost") || trimmed.hasPrefix("127.0.0.1") || trimmed.hasPrefix("0.0.0.0") {
            return URL(string: "http://\(trimmed)")
        }

        if trimmed.contains(".") && !trimmed.contains(" ") {
            return URL(string: "https://\(trimmed)")
        }

        let query = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: "https://www.google.com/search?q=\(query)")
    }
}
