import Foundation

enum CellValue: Sendable {
    case number(Double)
    case string(String)

    var displayLength: Int {
        switch self {
        case .number(let v):
            if v == v.rounded(.down) && v >= -999_999_999 && v <= 999_999_999 {
                return String(Int(v)).count
            }
            return String(v).count
        case .string(let s):
            return s.count
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
        guard let data = FileManager.default.contents(atPath: path) else { return "utf8" }
        let bytes = [UInt8](data.prefix(4))

        // Check BOM
        if bytes.count >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF {
            return "utf8"
        }
        if bytes.count >= 2 {
            if (bytes[0] == 0xFE && bytes[1] == 0xFF) || (bytes[0] == 0xFF && bytes[1] == 0xFE) {
                return "utf16"
            }
        }

        // Try UTF-8 — if it decodes cleanly, use it
        if String(data: data, encoding: .utf8) != nil {
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

        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .prefix(10)

        let candidates: [(Character, String)] = [(",", "comma"), (";", "semicolon"), ("\t", "tabulator")]
        var bestName = "comma"
        var bestScore = 0

        for (char, name) in candidates {
            // Count occurrences outside of quoted fields
            var total = 0
            for line in lines {
                var inQuotes = false
                for c in line {
                    if c == "\"" { inQuotes.toggle() }
                    else if c == char && !inQuotes { total += 1 }
                }
            }
            if total > bestScore {
                bestScore = total
                bestName = name
            }
        }

        return bestName
    }

    static func parse(fileAt path: String, delimiter: String, encodingTag: String = "auto") throws -> [[CellValue]] {
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
            let cells = fields.map { field -> CellValue in
                let trimmed = field.trimmingCharacters(in: .whitespaces)
                if let intVal = Int64(trimmed) {
                    return .number(Double(intVal))
                }
                if let doubleVal = Double(trimmed) {
                    return .number(doubleVal)
                }
                return .string(field)
            }
            rows.append(cells)
        }
        return rows
    }

    private static func parseLine(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
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
