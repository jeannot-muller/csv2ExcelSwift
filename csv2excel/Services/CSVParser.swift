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
    /// Detect the most likely delimiter by counting occurrences in the first few lines.
    static func detectDelimiter(fileAt path: String) -> String {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
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

    static func parse(fileAt path: String, delimiter: String) throws -> [[CellValue]] {
        let delimChar: Character = switch delimiter {
        case "semicolon": ";"
        case "tabulator": "\t"
        default: ","
        }

        let content = try String(contentsOfFile: path, encoding: .utf8)
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
