import Foundation

struct RecentFile: Codable, Identifiable {
    var id: String { path }
    let path: String
    let bookmark: Data

    var name: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    /// Resolve the bookmark to a URL with security-scoped access.
    func resolveURL() -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
