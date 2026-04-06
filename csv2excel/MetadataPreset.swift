import Foundation

struct MetadataPreset: Codable, Identifiable {
    var id = UUID()
    var name: String
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
