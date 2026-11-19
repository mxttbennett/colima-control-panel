import Foundation

public struct ReleaseInfo: Decodable, Equatable, Sendable {
    public let tag: String
    public let url: URL
    enum CodingKeys: String, CodingKey { case tag = "tag_name", url = "html_url" }
}

public enum UpdateOutcome: Equatable, Sendable {
    case upToDate
    case available(String)
    case development
    case unknown
}

public enum UpdateCheck {
    public static let latestReleaseURL = URL(string: "https://api.github.com/repos/mxttbennett/colima-control-panel/releases/latest")!
    public static let upgradeCommand = "brew upgrade --cask colima-control-panel"

    /// Asks GitHub for the newest published release; nil when the repository has none yet.
    public static func fetchLatest(session: URLSession = .shared) async throws -> ReleaseInfo? {
        var request = URLRequest(url: latestReleaseURL, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return nil }
        guard status == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(ReleaseInfo.self, from: data)
    }

    public static func outcome(installed: String, latestTag: String) -> UpdateOutcome {
        guard let latest = parse(latestTag) else { return .unknown }
        guard let current = parse(installed) else { return .development }
        let order = compare(current.numbers, latest.numbers)
        if order < 0 { return .available(latest.numbers.map(String.init).joined(separator: ".")) }
        return order == 0 && current.aheadOfTag ? .development : .upToDate
    }

    private static func parse(_ text: String) -> (numbers: [Int], aheadOfTag: Bool)? {
        let trimmed = text.hasPrefix("v") ? String(text.dropFirst()) : text
        let core = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        let numbers = core[0].split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !numbers.isEmpty, numbers.count <= 3, !numbers.contains(nil) else { return nil }
        return (numbers.compactMap { $0 }, core.count > 1)
    }

    private static func compare(_ a: [Int], _ b: [Int]) -> Int {
        for index in 0..<max(a.count, b.count) {
            let (x, y) = (index < a.count ? a[index] : 0, index < b.count ? b[index] : 0)
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }
}
