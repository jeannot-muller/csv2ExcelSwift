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
        let tmpdir = NSTemporaryDirectory()

        var options = lxw_workbook_options()
        let workbook: UnsafeMutablePointer<lxw_workbook>? = tmpdir.withCString { tmp in
            options.tmpdir = tmp
            return workbook_new_opt(path, &options)
        }
        guard let workbook else {
            throw XLSXError.cannotCreateWorkbook
        }

        // Set document properties
        setDocProperties(workbook, from: properties)

        // Add worksheet
        guard let worksheet = workbook_add_worksheet(workbook, sheetName) else {
            workbook_close(workbook)
            throw XLSXError.cannotCreateWorksheet
        }

        // Track column widths for autofit: (maxChars, isHeaderWidest)
        var columnWidths: [Int: (chars: Double, headerIsWidest: Bool)] = [:]

        // Write cell data
        for (rowIdx, row) in rows.enumerated() {
            let r = lxw_row_t(rowIdx)
            for (colIdx, cell) in row.enumerated() {
                let c = lxw_col_t(colIdx)
                let len: Double
                switch cell {
                case .number(let v):
                    worksheet_write_number(worksheet, r, c, v, nil)
                    len = Double(cell.displayLength)
                case .string(let s):
                    worksheet_write_string(worksheet, r, c, s, nil)
                    len = Double(s.count)
                }
                let prev = columnWidths[colIdx]
                if prev == nil || len > prev!.chars {
                    columnWidths[colIdx] = (len, rowIdx == 0)
                }
            }
        }

        // Apply column widths
        for (col, info) in columnWidths {
            let width = estimateColumnWidth(info.chars, isHeader: info.headerIsWidest)
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

    /// Estimate Excel column width from character count.
    /// Calibri 11pt: adds padding, bold bonus for headers, capped at 60.
    private static func estimateColumnWidth(_ charCount: Double, isHeader: Bool) -> Double {
        let base = charCount * 1.05 + 2.0
        let adjusted = isHeader ? base * 1.08 : base
        return min(max(adjusted, 8.0), 60.0)
    }

    /// Streaming session for writing rows one at a time without materializing the full array.
    struct Session {
        let workbook: UnsafeMutablePointer<lxw_workbook>
        let worksheet: UnsafeMutablePointer<lxw_worksheet>
        var columnWidths: [Int: (chars: Double, headerIsWidest: Bool)] = [:]
        var currentRow: Int = 0

        static func open(
            sheetName: String,
            properties: XLSXDocProperties,
            to url: URL
        ) throws -> Session {
            let path = url.path(percentEncoded: false)
            let tmpdir = NSTemporaryDirectory()

            var options = lxw_workbook_options()
            let workbook: UnsafeMutablePointer<lxw_workbook>? = tmpdir.withCString { tmp in
                options.tmpdir = tmp
                return workbook_new_opt(path, &options)
            }
            guard let workbook else {
                throw XLSXError.cannotCreateWorkbook
            }

            setDocProperties(workbook, from: properties)

            guard let worksheet = workbook_add_worksheet(workbook, sheetName) else {
                workbook_close(workbook)
                throw XLSXError.cannotCreateWorksheet
            }

            return Session(workbook: workbook, worksheet: worksheet)
        }

        mutating func addRow(_ cells: [CellValue]) {
            let r = lxw_row_t(currentRow)
            for (colIdx, cell) in cells.enumerated() {
                let c = lxw_col_t(colIdx)
                let len: Double
                switch cell {
                case .number(let v):
                    worksheet_write_number(worksheet, r, c, v, nil)
                    len = Double(cell.displayLength)
                case .string(let s):
                    worksheet_write_string(worksheet, r, c, s, nil)
                    len = Double(s.count)
                }
                let prev = columnWidths[colIdx]
                if prev == nil || len > prev!.chars {
                    columnWidths[colIdx] = (len, currentRow == 0)
                }
            }
            currentRow += 1
        }

        func finish() throws {
            // Apply column widths
            for (col, info) in columnWidths {
                let width = estimateColumnWidth(info.chars, isHeader: info.headerIsWidest)
                worksheet_set_column(worksheet, lxw_col_t(col), lxw_col_t(col), width, nil)
            }

            let error = workbook_close(workbook)
            if error != LXW_NO_ERROR {
                throw XLSXError.writeError(String(cString: lxw_strerror(error)))
            }
        }

        func cancel() {
            workbook_close(workbook)
        }
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
