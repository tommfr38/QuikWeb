import Foundation

/// Decides whether a query should be treated as a website address and opened
/// directly instead of being sent to the search engine.
///
/// The rule (per the feature spec): the ENTIRE query must be a single
/// `name.tld`-shaped token — "youtube.com" opens the site, but anything with
/// surrounding words ("is it safe github.com", "trustpilot github.com") is a
/// normal search. An optional http(s):// prefix and an optional /path, ?query,
/// or #fragment suffix after the host are allowed ("github.com/anthropics").
///
/// Deliberately Foundation-only (no AppKit) so the logic can be compiled and
/// tested standalone, outside the app.
enum WebsiteDetector {
    /// Returns the URL to open directly, or nil if the query should go to the
    /// search engine instead.
    static func directURL(for query: String) -> URL? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Any interior whitespace means it's a phrase, not an address.
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else { return nil }

        var rest = Substring(trimmed)
        var hadScheme = false
        for scheme in ["https://", "http://"] where rest.lowercased().hasPrefix(scheme) {
            rest = rest.dropFirst(scheme.count)
            hadScheme = true
            break
        }

        // Separate the host from any /path, ?query, or #fragment suffix.
        let hostEnd = rest.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? rest.endIndex
        guard isValidHost(rest[..<hostEnd]) else { return nil }

        return URL(string: hadScheme ? trimmed : "https://" + trimmed)
    }

    /// True when `host` is `label(.label)*.tld` with valid hostname labels and
    /// an alphabetic TLD of 2+ characters (so "1.5" or "v2.0" never match).
    private static func isValidHost(_ host: Substring) -> Bool {
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }

        for label in labels {
            guard !label.isEmpty, label.count <= 63,
                  label.first != "-", label.last != "-",
                  label.allSatisfy({ ($0.isLetter && $0.isASCII) || ($0.isNumber && $0.isASCII) || $0 == "-" })
            else { return false }
        }

        guard let tld = labels.last, tld.count >= 2,
              tld.allSatisfy({ $0.isLetter && $0.isASCII })
        else { return false }

        return true
    }
}
