import Foundation
import libxlsxwriter

struct XLSXDocProperties: Sendable {
    var title: String = ""
    var subject: String = ""
    var author: String = ""
    var manager: String = ""
    var company: String = ""
    var category: String = ""
    var keywords: String = ""
    var comment: String = ""
}

struct XLSXWriter {
    static func write(
        rows: [[CellValue]],
        sheetName: String,
        properties: XLSXDocProperties,
        to url: URL
    ) throws {
        let path = url.path(percentEncoded: false)

        guard let workbook = workbook_new(path) else {
            throw XLSXError.cannotCreateWorkbook
        }

        // Set document properties
        setDocProperties(workbook, from: properties)

        // Add worksheet
        guard let worksheet = workbook_add_worksheet(workbook, sheetName) else {
            workbook_close(workbook)
            throw XLSXError.cannotCreateWorksheet
        }

        // Track column widths for autofit
        var columnWidths: [Int: Double] = [:]

        // Write cell data
        for (rowIdx, row) in rows.enumerated() {
            let r = lxw_row_t(rowIdx)
            for (colIdx, cell) in row.enumerated() {
                let c = lxw_col_t(colIdx)
                switch cell {
                case .number(let v):
                    worksheet_write_number(worksheet, r, c, v, nil)
                    let len = Double(cell.displayLength)
                    columnWidths[colIdx] = max(columnWidths[colIdx] ?? 0, len)
                case .string(let s):
                    worksheet_write_string(worksheet, r, c, s, nil)
                    let len = Double(s.count)
                    columnWidths[colIdx] = max(columnWidths[colIdx] ?? 0, len)
                }
            }
        }

        // Apply column widths (approximate autofit)
        for (col, charWidth) in columnWidths {
            let width = max(charWidth * 1.1 + 1, 8.0)
            worksheet_set_column(worksheet, lxw_col_t(col), lxw_col_t(col), width, nil)
        }

        let error = workbook_close(workbook)
        if error != LXW_NO_ERROR {
            throw XLSXError.writeError(String(cString: lxw_strerror(error)))
        }
    }

    private static func setDocProperties(_ workbook: UnsafeMutablePointer<lxw_workbook>, from doc: XLSXDocProperties) {
        var props = lxw_doc_properties()

        // Use withCString to pass string pointers safely within the scope
        // We need all strings alive simultaneously, so we use nested closures
        let strings: [(String, WritableKeyPath<lxw_doc_properties, UnsafePointer<CChar>?>)] = [
            (doc.title, \.title),
            (doc.subject, \.subject),
            (doc.author, \.author),
            (doc.manager, \.manager),
            (doc.company, \.company),
            (doc.category, \.category),
            (doc.keywords, \.keywords),
            (doc.comment, \.comments),
        ]

        // Allocate C strings that persist through the call
        var cStrings: [UnsafeMutablePointer<CChar>] = []
        defer { cStrings.forEach { free($0) } }

        for (value, keyPath) in strings {
            if !value.isEmpty {
                let cStr = strdup(value)!
                cStrings.append(cStr)
                props[keyPath: keyPath] = UnsafePointer(cStr)
            }
        }

        workbook_set_properties(workbook, &props)
    }
}

enum XLSXError: LocalizedError {
    case cannotCreateWorkbook
    case cannotCreateWorksheet
    case writeError(String)

    var errorDescription: String? {
        switch self {
        case .cannotCreateWorkbook: "Failed to create Excel workbook."
        case .cannotCreateWorksheet: "Failed to create worksheet."
        case .writeError(let msg): "Excel write error: \(msg)"
        }
    }
}
