import Foundation

struct BatchFile: Identifiable {
    let id = UUID()
    let url: URL
    let bookmark: Data?
    var status: Status = .pending

    var name: String { url.lastPathComponent }
    var path: String { url.path(percentEncoded: false) }

    /// Create a BatchFile, storing a security-scoped bookmark for sandbox access.
    init(url: URL, status: Status = .pending) {
        self.url = url
        self.bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.status = status
    }

    /// Resolve the bookmark to a security-scoped URL.
    func resolveURL() -> URL? {
        guard let bookmark else { return url }
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    enum Status: Equatable {
        case pending
        case converting
        case done(duration: String)
        case error(message: String)
    }
}
