import SwiftUI

@Observable
final class AppState {
    var isDarkTheme: Bool = false
    var sourcePath: String = ""
    var destinationPath: String = ""
    var delimiter: String = "comma"
    var encoding: String = "auto"
    var sheetName: String = "csv2excel"
    var runTime: String = ""
    var xlsxTitle: String = ""
    var xlsxSubject: String = ""
    var xlsxAuthor: String = ""
    var xlsxManager: String = ""
    var xlsxCompany: String = ""
    var xlsxCategory: String = ""
    var xlsxKeywords: String = ""
    var xlsxComment: String = ""
    var headerColor: String = "A8D4F5"
    var sheetTabColor: String = "7F4DB5"
    var saveToSameLocation: Bool = false
    var smartTypes: Bool = true
    var decimalStyle: String = "auto"
    var hasHeaderRow: Bool = true
    var recentFiles: [RecentFile] = []
    var presets: [ExportPreset] = []
    var metadataPresets: [MetadataPreset] = []
    var sourceBookmark: Data?
    var destinationBookmark: Data?
    var defaultOutputDirectory: String = ""
    var defaultOutputBookmark: Data?

    // Transient state (not persisted)
    var hasConvertedOnce: Bool = false

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
        sheetName = d.string(forKey: "sheetName") ?? "csv2excel"
        runTime = d.string(forKey: "runTime") ?? ""
        xlsxTitle = d.string(forKey: "xlsxTitle") ?? ""
        xlsxSubject = d.string(forKey: "xlsxSubject") ?? ""
        xlsxAuthor = d.string(forKey: "xlsxAuthor") ?? ""
        xlsxManager = d.string(forKey: "xlsxManager") ?? ""
        xlsxCompany = d.string(forKey: "xlsxCompany") ?? ""
        xlsxCategory = d.string(forKey: "xlsxCategory") ?? ""
        xlsxKeywords = d.string(forKey: "xlsxKeywords") ?? ""
        xlsxComment = d.string(forKey: "xlsxComment") ?? ""
        headerColor = d.string(forKey: "headerColor") ?? "A8D4F5"
        sheetTabColor = d.string(forKey: "sheetTabColor") ?? "7F4DB5"
        saveToSameLocation = d.bool(forKey: "saveToSameLocation")
        smartTypes = d.object(forKey: "smartTypes") as? Bool ?? true
        decimalStyle = d.string(forKey: "decimalStyle") ?? "auto"
        hasHeaderRow = d.object(forKey: "hasHeaderRow") as? Bool ?? true
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
        defaultOutputDirectory = d.string(forKey: "defaultOutputDirectory") ?? ""
        defaultOutputBookmark = d.data(forKey: "defaultOutputBookmark")
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
        d.set(headerColor, forKey: "headerColor")
        d.set(sheetTabColor, forKey: "sheetTabColor")
        d.set(saveToSameLocation, forKey: "saveToSameLocation")
        d.set(smartTypes, forKey: "smartTypes")
        d.set(decimalStyle, forKey: "decimalStyle")
        d.set(hasHeaderRow, forKey: "hasHeaderRow")
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
        d.set(defaultOutputDirectory, forKey: "defaultOutputDirectory")
        d.set(defaultOutputBookmark, forKey: "defaultOutputBookmark")
    }

    func resolveSourceURL() -> URL? {
        resolveBookmark(data: sourceBookmark, isSource: true)
    }

    func resolveDestinationURL() -> URL? {
        resolveBookmark(data: destinationBookmark, isSource: false)
    }

    func resolveDefaultOutputURL() -> URL? {
        guard let data = defaultOutputBookmark else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            defaultOutputBookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            save()
        }
        return url
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
            smartTypes: smartTypes,
            decimalStyle: decimalStyle,
            hasHeaderRow: hasHeaderRow,
            xlsxTitle: xlsxTitle,
            xlsxSubject: xlsxSubject,
            xlsxAuthor: xlsxAuthor,
            xlsxManager: xlsxManager,
            xlsxCompany: xlsxCompany,
            xlsxCategory: xlsxCategory,
            xlsxKeywords: xlsxKeywords,
            xlsxComment: xlsxComment,
            headerColor: headerColor,
            sheetTabColor: sheetTabColor
        )
    }

    func applyPreset(_ preset: ExportPreset) {
        sheetName = preset.sheetName
        encoding = preset.encoding
        delimiter = preset.delimiter
        saveToSameLocation = preset.saveToSameLocation
        smartTypes = preset.smartTypes
        decimalStyle = preset.decimalStyle
        hasHeaderRow = preset.hasHeaderRow
        xlsxTitle = preset.xlsxTitle
        xlsxSubject = preset.xlsxSubject
        xlsxAuthor = preset.xlsxAuthor
        xlsxManager = preset.xlsxManager
        xlsxCompany = preset.xlsxCompany
        xlsxCategory = preset.xlsxCategory
        xlsxKeywords = preset.xlsxKeywords
        xlsxComment = preset.xlsxComment
        headerColor = preset.headerColor
        sheetTabColor = preset.sheetTabColor
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
            xlsxComment: xlsxComment,
            headerColor: headerColor,
            sheetTabColor: sheetTabColor
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
        headerColor = preset.headerColor
        sheetTabColor = preset.sheetTabColor
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
        headerColor = "A8D4F5"
        sheetTabColor = "7F4DB5"
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
        smartTypes = true
        decimalStyle = "auto"
        hasHeaderRow = true
        defaultOutputDirectory = ""
        defaultOutputBookmark = nil
        delimiter = "comma"
        encoding = "auto"
        sheetName = "csv2excel"
        xlsxTitle = ""
        xlsxSubject = ""
        xlsxAuthor = ""
        xlsxManager = ""
        xlsxCompany = ""
        xlsxCategory = ""
        xlsxKeywords = ""
        xlsxComment = ""
        headerColor = "A8D4F5"
        sheetTabColor = "7F4DB5"
        runTime = ""
        save()
    }
}
