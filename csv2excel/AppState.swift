import SwiftUI

@Observable
final class AppState {
    var isDarkTheme: Bool = false
    var sourcePath: String = ""
    var destinationPath: String = ""
    var delimiter: String = "comma"
    var encoding: String = "auto"
    var sheetName: String = "mySheet"
    var runTime: String = ""
    var xlsxTitle: String = ""
    var xlsxSubject: String = ""
    var xlsxAuthor: String = ""
    var xlsxManager: String = ""
    var xlsxCompany: String = ""
    var xlsxCategory: String = ""
    var xlsxKeywords: String = ""
    var xlsxComment: String = ""
    var sourceBookmark: Data?
    var destinationBookmark: Data?

    nonisolated(unsafe) private static let defaults = UserDefaults.standard

    init() {
        let d = Self.defaults
        isDarkTheme = d.bool(forKey: "isDarkTheme")
        sourcePath = ""
        destinationPath = ""
        delimiter = d.string(forKey: "delimiter") ?? "comma"
        encoding = d.string(forKey: "encoding") ?? "auto"
        sheetName = d.string(forKey: "sheetName") ?? "mySheet"
        runTime = d.string(forKey: "runTime") ?? ""
        xlsxTitle = d.string(forKey: "xlsxTitle") ?? ""
        xlsxSubject = d.string(forKey: "xlsxSubject") ?? ""
        xlsxAuthor = d.string(forKey: "xlsxAuthor") ?? ""
        xlsxManager = d.string(forKey: "xlsxManager") ?? ""
        xlsxCompany = d.string(forKey: "xlsxCompany") ?? ""
        xlsxCategory = d.string(forKey: "xlsxCategory") ?? ""
        xlsxKeywords = d.string(forKey: "xlsxKeywords") ?? ""
        xlsxComment = d.string(forKey: "xlsxComment") ?? ""
        sourceBookmark = d.data(forKey: "sourceBookmark")
        destinationBookmark = d.data(forKey: "destinationBookmark")
    }

    func save() {
        let d = Self.defaults
        d.set(isDarkTheme, forKey: "isDarkTheme")
        d.set(sourcePath, forKey: "sourcePath")
        d.set(destinationPath, forKey: "destinationPath")
        d.set(delimiter, forKey: "delimiter")
        d.set(encoding, forKey: "encoding")
        d.set(sheetName, forKey: "sheetName")
        d.set(runTime, forKey: "runTime")
        d.set(xlsxTitle, forKey: "xlsxTitle")
        d.set(xlsxSubject, forKey: "xlsxSubject")
        d.set(xlsxAuthor, forKey: "xlsxAuthor")
        d.set(xlsxManager, forKey: "xlsxManager")
        d.set(xlsxCompany, forKey: "xlsxCompany")
        d.set(xlsxCategory, forKey: "xlsxCategory")
        d.set(xlsxKeywords, forKey: "xlsxKeywords")
        d.set(xlsxComment, forKey: "xlsxComment")
        d.set(sourceBookmark, forKey: "sourceBookmark")
        d.set(destinationBookmark, forKey: "destinationBookmark")
    }

    func resolveSourceURL() -> URL? {
        resolveBookmark(data: sourceBookmark, isSource: true)
    }

    func resolveDestinationURL() -> URL? {
        resolveBookmark(data: destinationBookmark, isSource: false)
    }

    private func resolveBookmark(data: Data?, isSource: Bool) -> URL? {
        guard let data else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            let refreshed = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            if isSource { sourceBookmark = refreshed } else { destinationBookmark = refreshed }
            save()
        }
        return url
    }

    func reset() {
        sourcePath = ""
        destinationPath = ""
        sourceBookmark = nil
        destinationBookmark = nil
        delimiter = "comma"
        encoding = "auto"
        sheetName = "mySheet"
        xlsxTitle = ""
        xlsxSubject = ""
        xlsxAuthor = ""
        xlsxManager = ""
        xlsxCompany = ""
        xlsxCategory = ""
        xlsxKeywords = ""
        xlsxComment = ""
        runTime = ""
        save()
    }
}
