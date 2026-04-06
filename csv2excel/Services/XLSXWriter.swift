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
                case .date(let parsed):
                    var dt = lxw_datetime(
                        year: Int32(parsed.year), month: Int32(parsed.month), day: Int32(parsed.day),
                        hour: Int32(parsed.hour), min: Int32(parsed.minute), sec: parsed.second
                    )
                    let dateFmt = workbook_add_format(workbook)
                    parsed.excelFormat.withCString { format_set_num_format(dateFmt, $0) }
                    worksheet_write_datetime(worksheet, r, c, &dt, dateFmt)
                    len = Double(parsed.excelFormat.count + 2)
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
        let hasHeaderRow: Bool
        let boldFormat: UnsafeMutablePointer<lxw_format>?
        var columnWidths: [Int: (chars: Double, headerIsWidest: Bool)] = [:]
        var dateFormats: [String: UnsafeMutablePointer<lxw_format>] = [:]
        var currentRow: Int = 0
        var maxColCount: Int = 0

        static func open(
            sheetName: String,
            properties: XLSXDocProperties,
            hasHeaderRow: Bool = false,
            headerColor: UInt32? = nil,
            sheetTabColor: UInt32? = nil,
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

            let boldFmt: UnsafeMutablePointer<lxw_format>?
            if hasHeaderRow {
                boldFmt = workbook_add_format(workbook)
                format_set_bold(boldFmt)
                if let color = headerColor {
                    format_set_pattern(boldFmt, UInt8(LXW_PATTERN_SOLID.rawValue))
                    format_set_bg_color(boldFmt, color)
                }
            } else {
                boldFmt = nil
            }

            guard let worksheet = workbook_add_worksheet(workbook, sheetName) else {
                workbook_close(workbook)
                throw XLSXError.cannotCreateWorksheet
            }

            if let tabColor = sheetTabColor {
                worksheet_set_tab_color(worksheet, tabColor)
            }

            return Session(workbook: workbook, worksheet: worksheet, hasHeaderRow: hasHeaderRow, boldFormat: boldFmt)
        }

        mutating func addRow(_ cells: [CellValue]) {
            guard currentRow < 1_048_576 else { return }  // Excel max rows
            let r = lxw_row_t(currentRow)
            let isHeader = currentRow == 0 && hasHeaderRow
            let fmt = isHeader ? boldFormat : nil
            let cappedCells = cells.prefix(16_384)  // Excel max columns
            maxColCount = max(maxColCount, cappedCells.count)

            for (colIdx, cell) in cappedCells.enumerated() {
                let c = lxw_col_t(colIdx)
                let len: Double
                switch cell {
                case .number(let v):
                    worksheet_write_number(worksheet, r, c, v, fmt)
                    len = Double(cell.displayLength)
                case .string(let s):
                    worksheet_write_string(worksheet, r, c, s, fmt)
                    len = Double(s.count)
                case .date(let parsed):
                    if isHeader {
                        // Header row: write date as bold string (headers are labels, unlikely to be dates)
                        let dateStr = String(format: "%04d-%02d-%02d", parsed.year, parsed.month, parsed.day)
                        worksheet_write_string(worksheet, r, c, dateStr, fmt)
                        len = Double(dateStr.count)
                    } else if parsed.year == 0 {
                        // Time-only: write as fractional day number with time format
                        let fraction = (Double(parsed.hour) * 3600 + Double(parsed.minute) * 60 + parsed.second) / 86400.0
                        let timeFmt = getOrCreateDateFormat(parsed.excelFormat)
                        worksheet_write_number(worksheet, r, c, fraction, timeFmt)
                        len = Double(parsed.excelFormat.count + 2)
                    } else {
                        var dt = lxw_datetime(
                            year: Int32(parsed.year),
                            month: Int32(parsed.month),
                            day: Int32(parsed.day),
                            hour: Int32(parsed.hour),
                            min: Int32(parsed.minute),
                            sec: parsed.second
                        )
                        let dateFmt = getOrCreateDateFormat(parsed.excelFormat)
                        worksheet_write_datetime(worksheet, r, c, &dt, dateFmt)
                        len = Double(parsed.excelFormat.count + 2)
                    }
                }
                let prev = columnWidths[colIdx]
                if prev == nil || len > prev!.chars {
                    columnWidths[colIdx] = (len, currentRow == 0)
                }
            }
            currentRow += 1
        }

        mutating func getOrCreateDateFormat(_ excelFormat: String) -> UnsafeMutablePointer<lxw_format>? {
            if let existing = dateFormats[excelFormat] { return existing }
            let fmt = workbook_add_format(workbook)
            excelFormat.withCString { format_set_num_format(fmt, $0) }
            dateFormats[excelFormat] = fmt
            return fmt
        }

        func finish() throws {
            // Apply column widths
            for (col, info) in columnWidths {
                let width = estimateColumnWidth(info.chars, isHeader: info.headerIsWidest)
                worksheet_set_column(worksheet, lxw_col_t(col), lxw_col_t(col), width, nil)
            }

            // Auto-filter on header row
            if hasHeaderRow && currentRow > 0 && maxColCount > 0 {
                worksheet_autofilter(
                    worksheet, 0, 0,
                    lxw_row_t(currentRow - 1),
                    lxw_col_t(maxColCount - 1)
                )
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
