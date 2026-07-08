// data_converter.swift
import Foundation

let UNITS: [String: (name: String, factor: Double)] = [
    "b":   ("bit", 1.0/8),
    "B":   ("byte", 1),
    "KB":  ("kilobyte", 1000),
    "KiB": ("kibibyte", 1024),
    "MB":  ("megabyte", 1000*1000),
    "MiB": ("mebibyte", 1024*1024),
    "GB":  ("gigabyte", 1000*1000*1000),
    "GiB": ("gibibyte", 1024*1024*1024),
    "TB":  ("terabyte", 1000*1000*1000*1000),
    "TiB": ("tebibyte", 1024*1024*1024*1024),
    "PB":  ("petabyte", 1000*1000*1000*1000*1000),
    "PiB": ("pebibyte", 1024*1024*1024*1024*1024)
]
let UNIT_ORDER = ["b","B","KB","KiB","MB","MiB","GB","GiB","TB","TiB","PB","PiB"]

class DataConverter {
    var precision: Int
    var history: [String] = []

    init(precision: Int = 2) {
        self.precision = precision
    }

    func parseValueUnit(_ s: String) throws -> (value: Double, unit: String) {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        let pattern = try! NSRegularExpression(pattern: #"^([\d.]+)\s*([a-zA-Z]+)$"#)
        let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
        if let match = pattern.firstMatch(in: trimmed, range: nsRange) {
            let valStr = String(trimmed[Range(match.range(at: 1), in: trimmed)!])
            let unitStr = String(trimmed[Range(match.range(at: 2), in: trimmed)!]).uppercased()
            guard let val = Double(valStr) else { throw NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid number"]) }
            var unit: String? = nil
            for u in UNITS.keys {
                if u.uppercased() == unitStr { unit = u; break }
            }
            if unit == nil && unitStr.hasSuffix("B") && unitStr.count > 1 {
                let short = String(unitStr.dropLast())
                for u in UNITS.keys {
                    if u.uppercased() == short { unit = u; break }
                }
            }
            guard let found = unit else {
                throw NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown unit: \(unitStr)"])
            }
            return (val, found)
        } else {
            // try plain number
            if let val = Double(trimmed) {
                return (val, "B")
            }
            throw NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid format. Use 'value unit'."])
        }
    }

    func toBytes(_ value: Double, unit: String) -> Double {
        return value * UNITS[unit]!.factor
    }

    func fromBytes(_ bytes: Double, unit: String) -> Double {
        return bytes / UNITS[unit]!.factor
    }

    func convert(value: Double, fromUnit: String, toUnit: String) -> Double {
        let bytes = toBytes(value, unit: fromUnit)
        let result = fromBytes(bytes, unit: toUnit)
        history.append("\(format(value, unit: fromUnit)) -> \(format(result, unit: toUnit))")
        if history.count > 20 { history.removeFirst() }
        return result
    }

    func autoConvert(value: Double, unit: String) -> (value: Double, unit: String) {
        let bytes = toBytes(value, unit: unit)
        var bestUnit = "B"
        var bestVal = bytes
        for u in UNIT_ORDER {
            let v = bytes / UNITS[u]!.factor
            if v >= 1 && v < 1000 {
                bestUnit = u
                bestVal = v
                break
            }
        }
        if bestUnit == "B" && bytes < 1 {
            bestUnit = "b"
            bestVal = bytes / UNITS["b"]!.factor
        }
        return (bestVal, bestUnit)
    }

    func format(_ value: Double, unit: String) -> String {
        return String(format: "%.\(precision)f %@", value, unit)
    }

    func showHistory() {
        if history.isEmpty {
            print("No conversions yet.")
        } else {
            print("\n--- Conversion History (last 20) ---")
            for (i, h) in history.enumerated() {
                print("\(i+1). \(h)")
            }
        }
    }

    func printHelp() {
        print("\nSupported units:")
        for (u, info) in UNITS.sorted(by: { $0.key < $1.key }) {
            print("  \(u.padding(toLength: 4, withPad: " ", startingAt: 0)) = \(info.name) (factor \(info.factor))")
        }
    }
}

func main() {
    let converter = DataConverter(precision: 2)
    print("=== Data Unit Converter ===")
    while true {
        print("\n1. Convert single value")
        print("2. Batch convert from file")
        print("3. Show conversion history")
        print("4. Set precision (current: \(converter.precision))")
        print("5. Help / unit info")
        print("6. Exit")
        print("Choose: ", terminator: "")
        guard let choice = readLine()?.trimmingCharacters(in: .whitespaces) else { continue }
        switch choice {
        case "1":
            do {
                print("Enter value and unit (e.g., 1024 MB): ", terminator: "")
                guard let inp = readLine() else { break }
                let parsed = try converter.parseValueUnit(inp)
                print("Target unit (leave blank for auto): ", terminator: "")
                let target = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
                if !target.isEmpty {
                    var toUnit: String? = nil
                    for u in UNITS.keys {
                        if u.uppercased() == target.uppercased() { toUnit = u; break }
                    }
                    guard let foundTo = toUnit else {
                        print("Unknown target unit.")
                        break
                    }
                    let result = converter.convert(value: parsed.value, fromUnit: parsed.unit, toUnit: foundTo)
                    print("\nResult: \(converter.format(parsed.value, unit: parsed.unit)) = \(converter.format(result, unit: foundTo))")
                } else {
                    let auto = converter.autoConvert(value: parsed.value, unit: parsed.unit)
                    converter.history.append("\(converter.format(parsed.value, unit: parsed.unit)) -> \(converter.format(auto.value, unit: auto.unit))")
                    if converter.history.count > 20 { converter.history.removeFirst() }
                    print("\nResult: \(converter.format(parsed.value, unit: parsed.unit)) = \(converter.format(auto.value, unit: auto.unit))")
                }
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        case "2":
            print("Enter batch file path: ", terminator: "")
            guard let fname = readLine()?.trimmingCharacters(in: .whitespaces), !fname.isEmpty else { break }
            guard FileManager.default.fileExists(atPath: fname) else {
                print("File not found.")
                break
            }
            print("Target unit for all conversions (leave blank for auto): ", terminator: "")
            let target2 = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
            var toUnit2: String? = nil
            if !target2.isEmpty {
                for u in UNITS.keys {
                    if u.uppercased() == target2.uppercased() { toUnit2 = u; break }
                }
                if toUnit2 == nil {
                    print("Unknown target unit.")
                    break
                }
            }
            print("\nBatch results:")
            guard let content = try? String(contentsOfFile: fname) else { break }
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let l = line.trimmingCharacters(in: .whitespaces)
                if l.isEmpty { continue }
                do {
                    let parsed = try converter.parseValueUnit(l)
                    if let toU = toUnit2 {
                        let result = converter.convert(value: parsed.value, fromUnit: parsed.unit, toUnit: toU)
                        print("\(converter.format(parsed.value, unit: parsed.unit)) -> \(converter.format(result, unit: toU))")
                    } else {
                        let auto = converter.autoConvert(value: parsed.value, unit: parsed.unit)
                        print("\(converter.format(parsed.value, unit: parsed.unit)) -> \(converter.format(auto.value, unit: auto.unit))")
                    }
                } catch {
                    print("Skipping '\(l)': \(error.localizedDescription)")
                }
            }
        case "3":
            converter.showHistory()
        case "4":
            print("Enter number of decimal places: ", terminator: "")
            if let precStr = readLine(), let prec = Int(precStr), prec >= 0 {
                converter.precision = prec
                print("Precision updated.")
            } else {
                print("Invalid precision.")
            }
        case "5":
            converter.printHelp()
        case "6":
            print("Goodbye!")
            return
        default:
            print("Invalid choice.")
        }
    }
}

main()
