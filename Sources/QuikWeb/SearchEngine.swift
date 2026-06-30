import Foundation

enum SearchEngine: String, CaseIterable, Identifiable, Codable, Hashable {
    case google, bing, duckduckgo, yahoo, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .google: return "Google"
        case .bing: return "Bing"
        case .duckduckgo: return "DuckDuckGo"
        case .yahoo: return "Yahoo"
        case .custom: return "Custom"
        }
    }

    /// customTemplate is only consulted for `.custom` and must contain a
    /// `{query}` placeholder, e.g. "https://example.com/search?q={query}".
    func url(for query: String, customTemplate: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed

        switch self {
        case .google:
            return URL(string: "https://www.google.com/search?q=\(encoded)")
        case .bing:
            return URL(string: "https://www.bing.com/search?q=\(encoded)")
        case .duckduckgo:
            return URL(string: "https://duckduckgo.com/?q=\(encoded)")
        case .yahoo:
            return URL(string: "https://search.yahoo.com/search?p=\(encoded)")
        case .custom:
            let filled = customTemplate.replacingOccurrences(of: "{query}", with: encoded)
            return URL(string: filled)
        }
    }
}
