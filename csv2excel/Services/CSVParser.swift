import Foundation

enum DecimalStyle: String, Codable, CaseIterable, Sendable {
    case auto = "auto"
    case dot = "dot"       // 1,234.56
    case comma = "comma"   // 1.234,56

    /// Resolve "auto" using the CSV delimiter as signal.
    func resolved(csvDelimiter: String) -> DecimalStyle {
        if self != .auto { return self }
        // Semicolon/tab-delimited CSVs are almost always European (comma-decimal)
        return (csvDelimiter == "semicolon" || csvDelimiter == "tabulator") ? .comma : .dot
    }
}

struct ParsedDate: Sendable {
    let year: Int, month: Int, day: Int
    let hour: Int, minute: Int, second: Double
    let excelFormat: String  // e.g. "yyyy-mm-dd", "dd.mm.yyyy"
}

enum CellValue: Sendable {
    case number(Double)
    case string(String)
    case date(ParsedDate)

    var displayLength: Int {
        switch self {
        case .number(let v):
            if v == v.rounded(.down) && v >= -999_999_999 && v <= 999_999_999 {
                return String(Int(v)).count
            }
            return String(v).count
        case .string(let s):
            return s.count
        case .date(let d):
            return d.excelFormat.count
        }
    }
}

struct CSVParser {

    /// All supported encodings for the picker.
    static let supportedEncodings: [(name: String, tag: String)] = [
        ("Auto-Detect", "auto"),
        ("UTF-8", "utf8"),
        ("Latin-1 (ISO 8859-1)", "latin1"),
        ("Windows-1252", "windows1252"),
        ("Mac Roman", "macroman"),
        ("UTF-16", "utf16"),
    ]

    /// Read file contents as a String using the specified encoding tag.
    /// When `encodingTag` is "auto", detects encoding via BOM then tries UTF-8, then Windows-1252.
    static func readString(fileAt path: String, encodingTag: String) -> String? {
        if encodingTag == "auto" {
            return autoDetectAndRead(fileAt: path)
        }
        guard let encoding = swiftEncoding(for: encodingTag) else { return nil }
        return try? String(contentsOfFile: path, encoding: encoding)
    }

    /// Detect encoding from file bytes: check BOM, try UTF-8, fallback to Windows-1252.
    static func detectEncoding(fileAt path: String) -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else { return "utf8" }
        defer { handle.closeFile() }

        // Read only what we need for BOM + UTF-8 trial
        let bomData = handle.readData(ofLength: 4)
        let bytes = [UInt8](bomData)

        // Check BOM
        if bytes.count >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF {
            return "utf8"
        }
        if bytes.count >= 2 {
            if (bytes[0] == 0xFE && bytes[1] == 0xFF) || (bytes[0] == 0xFF && bytes[1] == 0xFE) {
                return "utf16"
            }
        }

        // Try UTF-8 on a sample (first 8KB) — if it decodes cleanly, use it
        handle.seek(toFileOffset: 0)
        let sample = handle.readData(ofLength: 8192)
        if String(data: sample, encoding: .utf8) != nil {
            return "utf8"
        }

        // Fallback: Windows-1252 is the most common non-UTF-8 encoding for European CSVs
        return "windows1252"
    }

    private static func autoDetectAndRead(fileAt path: String) -> String? {
        let tag = detectEncoding(fileAt: path)
        guard let encoding = swiftEncoding(for: tag) else { return nil }
        return try? String(contentsOfFile: path, encoding: encoding)
    }

    private static func swiftEncoding(for tag: String) -> String.Encoding? {
        switch tag {
        case "utf8": return .utf8
        case "latin1": return .isoLatin1
        case "windows1252": return .windowsCP1252
        case "macroman": return .macOSRoman
        case "utf16": return .utf16
        default: return .utf8
        }
    }

    /// Detect the most likely delimiter by counting occurrences in the first few lines.
    static func detectDelimiter(fileAt path: String, encodingTag: String = "auto") -> String {
        guard let content = readString(fileAt: path, encodingTag: encodingTag) else {
            return "comma"
        }
        return detectDelimiter(in: content)
    }

    /// Detect delimiter from already-loaded content.
    static func detectDelimiter(in content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .prefix(10)

        let candidates: [(Character, String)] = [(",", "comma"), (";", "semicolon"), ("\t", "tabulator")]
        var bestName = "comma"
        var bestScore = 0

        for (char, name) in candidates {
            // Count occurrences outside of quoted fields (RFC 4180 aware)
            var total = 0
            for line in lines {
                var inQuotes = false
                var prevWasQuote = false
                for c in line {
                    if prevWasQuote {
                        prevWasQuote = false
                        if c == "\"" {
                            // Escaped quote "" — stay in quotes
                            continue
                        }
                        inQuotes = false
                        if c == char { total += 1 }
                        continue
                    }
                    if c == "\"" {
                        if inQuotes {
                            prevWasQuote = true
                        } else {
                            inQuotes = true
                        }
                    } else if c == char && !inQuotes {
                        total += 1
                    }
                }
            }
            if total > bestScore {
                bestScore = total
                bestName = name
            }
        }

        return bestName
    }

    /// Read file once, detect delimiter, and return preview rows + total line count.
    static func detectAndPreview(
        fileAt path: String,
        encodingTag: String = "auto",
        maxPreviewLines: Int = 5
    ) -> (delimiter: String, previewRows: [[String]], totalLines: Int)? {
        guard let content = readString(fileAt: path, encodingTag: encodingTag) else {
            return nil
        }

        let delimiter = detectDelimiter(in: content)
        let delimChar: Character = switch delimiter {
        case "semicolon": ";"
        case "tabulator": "\t"
        default: ","
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let previewRows = lines.prefix(maxPreviewLines).map { parseLine($0, delimiter: delimChar) }

        return (delimiter, previewRows, lines.count)
    }

    /// Re-parse preview rows from file with a specific delimiter (for manual override).
    static func previewRows(
        fileAt path: String,
        encodingTag: String = "auto",
        delimiter: String,
        maxLines: Int = 5
    ) -> (rows: [[String]], totalLines: Int)? {
        guard let content = readString(fileAt: path, encodingTag: encodingTag) else {
            return nil
        }

        let delimChar: Character = switch delimiter {
        case "semicolon": ";"
        case "tabulator": "\t"
        default: ","
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let rows = lines.prefix(maxLines).map { parseLine($0, delimiter: delimChar) }
        return (rows, lines.count)
    }

    static func parse(fileAt path: String, delimiter: String, encodingTag: String = "auto", smartTypes: Bool = true, decimalStyle: DecimalStyle = .dot) throws -> [[CellValue]] {
        let delimChar: Character = switch delimiter {
        case "semicolon": ";"
        case "tabulator": "\t"
        default: ","
        }

        guard let content = readString(fileAt: path, encodingTag: encodingTag) else {
            throw NSError(domain: "CSVParser", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unable to read file with the selected encoding. Try a different encoding."
            ])
        }
        var rows: [[CellValue]] = []

        for line in content.components(separatedBy: .newlines) {
            if line.isEmpty { continue }
            let fields = parseLine(line, delimiter: delimChar)
            let cells = fields.map { fieldToCellValue($0, smartTypes: smartTypes, decimalStyle: decimalStyle) }
            rows.append(cells)
        }
        return rows
    }

    /// Stream-parse a CSV file in chunks, calling `rowHandler` for each parsed row.
    /// Supports Task cancellation via `try Task.checkCancellation()` between chunks.
    static func parseStreaming(
        fileAt path: String,
        delimiter: String,
        encodingTag: String = "auto",
        smartTypes: Bool = true,
        decimalStyle: DecimalStyle = .dot,
        rowHandler: ([CellValue]) throws -> Void
    ) throws {
        let delimChar: Character = switch delimiter {
        case "semicolon": ";"
        case "tabulator": "\t"
        default: ","
        }

        // Resolve encoding
        let resolvedTag = encodingTag == "auto" ? detectEncoding(fileAt: path) : encodingTag
        guard let encoding = swiftEncoding(for: resolvedTag) else {
            throw NSError(domain: "CSVParser", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unsupported encoding."
            ])
        }

        guard let handle = FileHandle(forReadingAtPath: path) else {
            throw NSError(domain: "CSVParser", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Unable to open file for reading."
            ])
        }
        defer { handle.closeFile() }

        let chunkSize = 1_048_576 // 1MB
        var leftover = ""
        var inQuotes = false

        while true {
            try Task.checkCancellation()

            guard let data = try? handle.read(upToCount: chunkSize), !data.isEmpty else {
                break
            }

            guard let chunk = String(data: data, encoding: encoding) else { continue }
            let text = leftover + chunk
            leftover = ""

            // Iterate over Unicode scalars, not Characters: Swift treats "\r\n" as a
            // single grapheme cluster, so Character comparisons against "\r" or "\n"
            // both return false for CRLF — which silently swallows every line break
            // in Windows-style CSVs.
            let scalars = text.unicodeScalars
            var lineStart = scalars.startIndex
            var i = scalars.startIndex

            while i < scalars.endIndex {
                let scalar = scalars[i]
                if scalar == "\"" {
                    inQuotes.toggle()
                } else if !inQuotes && (scalar == "\n" || scalar == "\r") {
                    let line = String(scalars[lineStart..<i])
                    if !line.isEmpty {
                        let fields = parseLine(line, delimiter: delimChar)
                        let cells = fields.map { fieldToCellValue($0, smartTypes: smartTypes, decimalStyle: decimalStyle) }
                        try rowHandler(cells)
                    }
                    // Skip \r\n pair
                    let next = scalars.index(after: i)
                    if scalar == "\r" && next < scalars.endIndex && scalars[next] == "\n" {
                        i = next
                    }
                    lineStart = scalars.index(after: i)
                }
                i = scalars.index(after: i)
            }

            // Whatever remains goes to leftover for next chunk
            if lineStart < scalars.endIndex {
                leftover = String(scalars[lineStart...])
            }
        }

        // Process any remaining leftover
        if !leftover.isEmpty {
            let fields = parseLine(leftover, delimiter: delimChar)
            let cells = fields.map { fieldToCellValue($0, smartTypes: smartTypes, decimalStyle: decimalStyle) }
            try rowHandler(cells)
        }
    }

    static func fieldToCellValue(_ field: String, smartTypes: Bool = true, decimalStyle: DecimalStyle = .dot) -> CellValue {
        guard smartTypes else { return .string(field) }

        let trimmed = field.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .string(field) }

        // Preserve leading zeros (ZIP codes, SKUs, bank codes)
        if trimmed.count > 1 && trimmed.first == "0" && !trimmed.hasPrefix("0.") && !trimmed.hasPrefix("0,") {
            return .string(field)
        }

        // Try locale-aware number parsing
        if let number = parseNumber(trimmed, decimalStyle: decimalStyle) {
            return .number(number)
        }

        // Try date detection
        if let parsed = fieldToDate(trimmed, decimalStyle: decimalStyle) {
            return .date(parsed)
        }

        return .string(field)
    }

    /// Parse a number string according to the decimal style.
    private static func parseNumber(_ trimmed: String, decimalStyle: DecimalStyle) -> Double? {
        // Skip obvious non-numbers: currency, percentage, alpha-heavy
        guard let first = trimmed.first, first == "-" || first == "+" || first.isNumber else {
            return nil
        }
        if trimmed.hasSuffix("%") || trimmed.hasSuffix("€") || trimmed.hasSuffix("$") {
            return nil
        }

        let normalized: String
        switch decimalStyle {
        case .comma:
            // European: dots/spaces/apostrophes are thousands, comma is decimal
            normalized = trimmed
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\u{00A0}", with: "")  // non-breaking space
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: ",", with: ".")
        case .dot, .auto:
            // US/UK/ISO: commas/spaces are thousands, dot is decimal
            normalized = trimmed
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "\u{00A0}", with: "")
                .replacingOccurrences(of: "'", with: "")
        }

        // Reject degenerate inputs like "1.2.3" (multiple decimal points after normalization)
        if normalized.filter({ $0 == "." }).count > 1 { return nil }

        guard let value = Double(normalized) else { return nil }

        // Check integer precision loss (>2^53)
        if normalized.allSatisfy({ $0.isNumber || $0 == "-" || $0 == "+" }) {
            if let intVal = Int64(normalized), abs(intVal) > 9_007_199_254_740_992 {
                return nil
            }
        }

        return value
    }

    // MARK: - Date Detection

    private static let monthAbbreviations: [String: Int] = [
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
        "january": 1, "february": 2, "march": 3, "april": 4,
        "june": 6, "july": 7, "august": 8, "september": 9,
        "october": 10, "november": 11, "december": 12,
    ]

    // Swift Regex patterns (compiled once as static). Marked nonisolated(unsafe) for Swift 6 — Regex isn't Sendable but these are immutable.
    nonisolated(unsafe) private static let isoDateTimeRegex = /^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?)?(?:Z|[+-]\d{2}:?\d{2})?$/
    nonisolated(unsafe) private static let euDotRegex = /^(\d{1,2})\.(\d{1,2})\.(\d{4})$/
    nonisolated(unsafe) private static let euDotShortRegex = /^(\d{1,2})\.(\d{1,2})\.(\d{2})$/
    nonisolated(unsafe) private static let slashRegex = /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/
    nonisolated(unsafe) private static let slashShortRegex = /^(\d{1,2})\/(\d{1,2})\/(\d{2})$/
    nonisolated(unsafe) private static let dashRegex = /^(\d{1,2})-(\d{1,2})-(\d{4})$/
    nonisolated(unsafe) private static let textMonthDMYRegex = /^(\d{1,2})[\s-]([A-Za-z]+)[\s-](\d{4})$/
    nonisolated(unsafe) private static let textMonthMDYRegex = /^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})$/
    nonisolated(unsafe) private static let timeOnlyRegex = /^(\d{1,2}):(\d{2})(?::(\d{2}))?$/

    static func fieldToDate(_ field: String, decimalStyle: DecimalStyle) -> ParsedDate? {
        let s = field.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        // Short-circuit: if first char is not a digit and not a letter (for text months), skip
        guard let first = s.first, first.isNumber || first.isLetter else { return nil }

        // 1. ISO: yyyy-MM-dd[Thh:mm:ss[.fff]][Z|+hh:mm]
        if let m = s.wholeMatch(of: isoDateTimeRegex) {
            let y = Int(m.1)!, mo = Int(m.2)!, d = Int(m.3)!
            let h = m.4.map { Int($0)! } ?? 0
            let mi = m.5.map { Int($0)! } ?? 0
            let sec: Double
            if let secStr = m.6 {
                let baseSec = Double(secStr)!
                if let frac = m.7 {
                    let fracVal = Double("0.\(frac)")!
                    sec = baseSec + fracVal
                } else {
                    sec = baseSec
                }
            } else {
                sec = 0
            }
            guard validateDate(y: y, m: mo, d: d, h: h, mi: mi) else { return nil }
            let fmt = (h > 0 || mi > 0 || sec > 0) ? "yyyy-mm-dd hh:mm:ss" : "yyyy-mm-dd"
            return ParsedDate(year: y, month: mo, day: d, hour: h, minute: mi, second: sec, excelFormat: fmt)
        }

        // 2. Text month: "15-Mar-2024", "15 March 2024"
        if let m = s.wholeMatch(of: textMonthDMYRegex) {
            let d = Int(m.1)!
            guard let mo = monthAbbreviations[String(m.2).lowercased()] else { return nil }
            let y = Int(m.3)!
            guard validateDate(y: y, m: mo, d: d) else { return nil }
            return ParsedDate(year: y, month: mo, day: d, hour: 0, minute: 0, second: 0, excelFormat: "dd-mmm-yyyy")
        }

        // 3. Text month US: "Mar 15, 2024", "March 15 2024"
        if let m = s.wholeMatch(of: textMonthMDYRegex) {
            guard let mo = monthAbbreviations[String(m.1).lowercased()] else { return nil }
            let d = Int(m.2)!
            let y = Int(m.3)!
            guard validateDate(y: y, m: mo, d: d) else { return nil }
            return ParsedDate(year: y, month: mo, day: d, hour: 0, minute: 0, second: 0, excelFormat: "dd-mmm-yyyy")
        }

        // 4. European dots: dd.MM.yyyy (unambiguous — dots are always European)
        if let m = s.wholeMatch(of: euDotRegex) {
            let d = Int(m.1)!, mo = Int(m.2)!, y = Int(m.3)!
            guard validateDate(y: y, m: mo, d: d) else { return nil }
            return ParsedDate(year: y, month: mo, day: d, hour: 0, minute: 0, second: 0, excelFormat: "dd.mm.yyyy")
        }

        // 5. European dots short: dd.MM.yy
        if let m = s.wholeMatch(of: euDotShortRegex) {
            let d = Int(m.1)!, mo = Int(m.2)!, y = pivotYear(Int(m.3)!)
            guard validateDate(y: y, m: mo, d: d) else { return nil }
            return ParsedDate(year: y, month: mo, day: d, hour: 0, minute: 0, second: 0, excelFormat: "dd.mm.yyyy")
        }

        // 6. Slash dates: region-dependent
        if let m = s.wholeMatch(of: slashRegex) {
            let a = Int(m.1)!, b = Int(m.2)!, y = Int(m.3)!
            return parseAmbiguousDate(a: a, b: b, year: y, decimalStyle: decimalStyle, separator: "/")
        }

        // 7. Slash short
        if let m = s.wholeMatch(of: slashShortRegex) {
            let a = Int(m.1)!, b = Int(m.2)!, y = pivotYear(Int(m.3)!)
            return parseAmbiguousDate(a: a, b: b, year: y, decimalStyle: decimalStyle, separator: "/")
        }

        // 8. Dash non-ISO: d-M-yyyy (only if not ISO shaped)
        if let m = s.wholeMatch(of: dashRegex) {
            let a = Int(m.1)!, b = Int(m.2)!, y = Int(m.3)!
            return parseAmbiguousDate(a: a, b: b, year: y, decimalStyle: decimalStyle, separator: "-")
        }

        // 9. Time only: HH:mm[:ss]
        if let m = s.wholeMatch(of: timeOnlyRegex) {
            let h = Int(m.1)!, mi = Int(m.2)!
            let sec = m.3.map { Double($0)! } ?? 0
            guard h >= 0 && h <= 23 && mi >= 0 && mi <= 59 && sec >= 0 && sec < 60 else { return nil }
            return ParsedDate(year: 0, month: 0, day: 0, hour: h, minute: mi, second: sec, excelFormat: "hh:mm:ss")
        }

        return nil
    }

    /// Resolve dd/MM vs MM/dd ambiguity based on decimal style (as regional proxy).
    private static func parseAmbiguousDate(a: Int, b: Int, year: Int, decimalStyle: DecimalStyle, separator: String) -> ParsedDate? {
        let excelSep = separator == "/" ? "/" : "-"
        if decimalStyle == .comma {
            // European: dd/MM/yyyy
            guard validateDate(y: year, m: b, d: a) else { return nil }
            return ParsedDate(year: year, month: b, day: a, hour: 0, minute: 0, second: 0, excelFormat: "dd\(excelSep)mm\(excelSep)yyyy")
        } else {
            // US: MM/dd/yyyy
            guard validateDate(y: year, m: a, d: b) else { return nil }
            return ParsedDate(year: year, month: a, day: b, hour: 0, minute: 0, second: 0, excelFormat: "mm\(excelSep)dd\(excelSep)yyyy")
        }
    }

    private static func validateDate(y: Int, m: Int, d: Int, h: Int = 0, mi: Int = 0) -> Bool {
        guard y >= 1900 && y <= 9999 else { return false }
        guard m >= 1 && m <= 12 else { return false }
        guard d >= 1 else { return false }
        guard h >= 0 && h <= 23 else { return false }
        guard mi >= 0 && mi <= 59 else { return false }
        let isLeap = (y % 4 == 0 && y % 100 != 0) || (y % 400 == 0)
        let maxDays = [0, 31, isLeap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        guard d <= maxDays[m] else { return false }
        return true
    }

    private static func pivotYear(_ yy: Int) -> Int {
        yy <= 29 ? 2000 + yy : 1900 + yy
    }

    // MARK: - CSV Line Parsing

    static func parseLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var previousWasQuote = false

        for char in line {
            if previousWasQuote {
                previousWasQuote = false
                if char == "\"" {
                    // Escaped quote: "" -> literal "
                    current.append("\"")
                    continue
                } else {
                    // Closing quote was the end of the field
                    inQuotes = false
                    if char == delimiter {
                        fields.append(current)
                        current = ""
                        continue
                    }
                    current.append(char)
                    continue
                }
            }
            if char == "\"" {
                if inQuotes {
                    previousWasQuote = true
                } else if current.isEmpty {
                    inQuotes = true
                } else {
                    current.append(char)
                }
            } else if char == delimiter && !inQuotes {
                fields.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current)
        return fields
    }
}
