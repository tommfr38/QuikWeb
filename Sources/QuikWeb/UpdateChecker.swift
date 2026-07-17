import Foundation

/// Checks GitHub Releases for a newer version of QuikWeb. The app makes no
/// network requests of its own except this one, and only when the user
/// explicitly clicks "Check for Updates" in the About tab.
enum UpdateChecker {
    static let repo = "tommfr38/QuikWeb"
    static let releasesPageURL = URL(string: "https://github.com/\(repo)/releases/latest")!

    enum CheckResult {
        case upToDate(current: String)
        case updateAvailable(latest: String, url: URL)
        case failed(String)
    }

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private struct LatestRelease: Decodable {
        let tag_name: String
        let html_url: String
    }

    /// Fetches the latest release tag and compares it to the running version.
    /// `completion` is always invoked on the main thread.
    static func check(completion: @escaping (CheckResult) -> Void) {
        func finish(_ result: CheckResult) {
            DispatchQueue.main.async { completion(result) }
        }

        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else {
            finish(.failed("Invalid update URL"))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("QuikWeb", forHTTPHeaderField: "User-Agent") // GitHub requires a UA
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                finish(.failed(error.localizedDescription))
                return
            }
            guard let http = response as? HTTPURLResponse else {
                finish(.failed("No response from the update server"))
                return
            }
            guard http.statusCode == 200 else {
                finish(.failed("Update server returned status \(http.statusCode)"))
                return
            }
            guard let data = data,
                  let release = try? JSONDecoder().decode(LatestRelease.self, from: data) else {
                finish(.failed("Couldn't read the update information"))
                return
            }

            let latest = normalize(release.tag_name)
            if compare(latest, currentVersion) == .orderedDescending {
                let pageURL = URL(string: release.html_url) ?? releasesPageURL
                finish(.updateAvailable(latest: latest, url: pageURL))
            } else {
                finish(.upToDate(current: currentVersion))
            }
        }.resume()
    }

    /// Strips a leading "v"/"V" and surrounding whitespace: "v1.2.0" -> "1.2.0".
    static func normalize(_ tag: String) -> String {
        var s = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.first == "v" || s.first == "V" { s.removeFirst() }
        return s
    }

    /// Numeric, component-wise comparison of dotted version strings. Missing
    /// trailing components count as 0 ("1.2" == "1.2.0"), and each component
    /// is compared as an integer so "1.10.0" correctly sorts above "1.9.0".
    static func compare(_ a: String, _ b: String) -> ComparisonResult {
        let ac = a.split(separator: ".").map { Int($0) ?? 0 }
        let bc = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(ac.count, bc.count) {
            let av = i < ac.count ? ac[i] : 0
            let bv = i < bc.count ? bc[i] : 0
            if av != bv { return av < bv ? .orderedAscending : .orderedDescending }
        }
        return .orderedSame
    }
}
