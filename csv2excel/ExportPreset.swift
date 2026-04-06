import Foundation

struct ExportPreset: Codable, Identifiable {
    var id = UUID()
    var name: String
    var sheetName: String
    var encoding: String
    var delimiter: String
    var saveToSameLocation: Bool
    var smartTypes: Bool = true
    var decimalStyle: String = "auto"
    var hasHeaderRow: Bool = true
    var xlsxTitle: String
    var xlsxSubject: String
    var xlsxAuthor: String
    var xlsxManager: String
    var xlsxCompany: String
    var xlsxCategory: String
    var xlsxKeywords: String
    var xlsxComment: String
    var headerColor: String = ""
    var sheetTabColor: String = ""
}
