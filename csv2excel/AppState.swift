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
    var saveToSameLocation: Bool = false
    var recentFiles: [RecentFile] = []
    var presets: [ExportPreset] = []
    var metadataPresets: [MetadataPreset] = []
    var sourceBookmark: Data?
    var destinationBookmark: Data?

    // Cached preview data (not persisted — populated on file open)
    var cachedPreviewRows: [[String]] = []
    var cachedTotalRows: Int = 0

    // Batch mode
    var batchFiles: [BatchFile] = []
    var isBatchMode: Bool { batchFiles.count > 1 }

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
        saveToSameLocation = d.bool(forKey: "saveToSameLocation")
        if let recentData = d.data(forKey: "recentFiles"),
           let decoded = try? JSONDecoder().decode([RecentFile].self, from: recentData) {
            recentFiles = decoded
        }
        if let presetsData = d.data(forKey: "presets"),
           let decoded = try? JSONDecoder().decode([ExportPreset].self, from: presetsData) {
            presets = decoded
        }
        if let metaPresetsData = d.data(forKey: "metadataPresets"),
           let decoded = try? JSONDecoder().decode([MetadataPreset].self, from: metaPresetsData) {
            metadataPresets = decoded
        }
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
        d.set(saveToSameLocation, forKey: "saveToSameLocation")
        if let recentData = try? JSONEncoder().encode(recentFiles) {
            d.set(recentData, forKey: "recentFiles")
        }
        if let presetsData = try? JSONEncoder().encode(presets) {
            d.set(presetsData, forKey: "presets")
        }
        if let metaPresetsData = try? JSONEncoder().encode(metadataPresets) {
            d.set(metaPresetsData, forKey: "metadataPresets")
        }
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

    func createPreset(name: String) -> ExportPreset {
        ExportPreset(
            name: name,
            sheetName: sheetName,
            encoding: encoding,
            delimiter: delimiter,
            saveToSameLocation: saveToSameLocation,
            xlsxTitle: xlsxTitle,
            xlsxSubject: xlsxSubject,
            xlsxAuthor: xlsxAuthor,
            xlsxManager: xlsxManager,
            xlsxCompany: xlsxCompany,
            xlsxCategory: xlsxCategory,
            xlsxKeywords: xlsxKeywords,
            xlsxComment: xlsxComment
        )
    }

    func applyPreset(_ preset: ExportPreset) {
        sheetName = preset.sheetName
        encoding = preset.encoding
        delimiter = preset.delimiter
        saveToSameLocation = preset.saveToSameLocation
        xlsxTitle = preset.xlsxTitle
        xlsxSubject = preset.xlsxSubject
        xlsxAuthor = preset.xlsxAuthor
        xlsxManager = preset.xlsxManager
        xlsxCompany = preset.xlsxCompany
        xlsxCategory = preset.xlsxCategory
        xlsxKeywords = preset.xlsxKeywords
        xlsxComment = preset.xlsxComment
        save()
    }

    func createMetadataPreset(name: String) -> MetadataPreset {
        MetadataPreset(
            name: name,
            xlsxTitle: xlsxTitle,
            xlsxSubject: xlsxSubject,
            xlsxAuthor: xlsxAuthor,
            xlsxManager: xlsxManager,
            xlsxCompany: xlsxCompany,
            xlsxCategory: xlsxCategory,
            xlsxKeywords: xlsxKeywords,
            xlsxComment: xlsxComment
        )
    }

    func applyMetadataPreset(_ preset: MetadataPreset) {
        xlsxTitle = preset.xlsxTitle
        xlsxSubject = preset.xlsxSubject
        xlsxAuthor = preset.xlsxAuthor
        xlsxManager = preset.xlsxManager
        xlsxCompany = preset.xlsxCompany
        xlsxCategory = preset.xlsxCategory
        xlsxKeywords = preset.xlsxKeywords
        xlsxComment = preset.xlsxComment
        save()
    }

    func addRecentFile(url: URL) {
        let path = url.path(percentEncoded: false)
        guard let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        recentFiles.removeAll { $0.path == path }
        recentFiles.insert(RecentFile(path: path, bookmark: bookmark), at: 0)
        if recentFiles.count > 10 {
            recentFiles = Array(recentFiles.prefix(10))
        }
        save()
    }

    func clearMetadata() {
        xlsxTitle = ""
        xlsxSubject = ""
        xlsxAuthor = ""
        xlsxManager = ""
        xlsxCompany = ""
        xlsxCategory = ""
        xlsxKeywords = ""
        xlsxComment = ""
        save()
    }

    func reset() {
        sourcePath = ""
        destinationPath = ""
        sourceBookmark = nil
        destinationBookmark = nil
        batchFiles = []
        cachedPreviewRows = []
        cachedTotalRows = 0
        saveToSameLocation = false
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
