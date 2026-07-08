// DataConverter.cs
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;

class UnitInfo
{
    public string Name { get; set; }
    public double Factor { get; set; }
}

class DataConverter
{
    private static readonly Dictionary<string, UnitInfo> Units = new Dictionary<string, UnitInfo>
    {
        {"b", new UnitInfo{Name="bit", Factor=1.0/8}},
        {"B", new UnitInfo{Name="byte", Factor=1}},
        {"KB", new UnitInfo{Name="kilobyte", Factor=1000}},
        {"KiB", new UnitInfo{Name="kibibyte", Factor=1024}},
        {"MB", new UnitInfo{Name="megabyte", Factor=1000*1000}},
        {"MiB", new UnitInfo{Name="mebibyte", Factor=1024*1024}},
        {"GB", new UnitInfo{Name="gigabyte", Factor=1000*1000*1000}},
        {"GiB", new UnitInfo{Name="gibibyte", Factor=1024*1024*1024}},
        {"TB", new UnitInfo{Name="terabyte", Factor=1000L*1000*1000*1000}},
        {"TiB", new UnitInfo{Name="tebibyte", Factor=1024L*1024*1024*1024}},
        {"PB", new UnitInfo{Name="petabyte", Factor=1000L*1000*1000*1000*1000}},
        {"PiB", new UnitInfo{Name="pebibyte", Factor=1024L*1024*1024*1024*1024}}
    };

    private int precision;
    private List<string> history = new List<string>();

    public DataConverter(int prec = 2) { precision = prec; }

    private (double value, string unit) ParseValueUnit(string s)
    {
        s = s.Trim();
        var m = Regex.Match(s, @"^([\d.]+)\s*([a-zA-Z]+)$");
        if (!m.Success)
        {
            // try just number
            if (double.TryParse(s, out double val))
                return (val, "B");
            throw new Exception("Invalid format. Use 'value unit'.");
        }
        double val2 = double.Parse(m.Groups[1].Value);
        string unitStr = m.Groups[2].Value.ToUpper();
        // normalize
        foreach (var u in Units.Keys)
        {
            if (string.Equals(u, unitStr, StringComparison.OrdinalIgnoreCase))
                return (val2, u);
        }
        // try alias: remove trailing 'B'
        if (unitStr.EndsWith("B") && unitStr.Length > 1)
        {
            string shortU = unitStr.Substring(0, unitStr.Length - 1);
            foreach (var u in Units.Keys)
            {
                if (string.Equals(u, shortU, StringComparison.OrdinalIgnoreCase))
                    return (val2, u);
            }
        }
        throw new Exception($"Unknown unit: {unitStr}");
    }

    private double ToBytes(double value, string unit) => value * Units[unit].Factor;
    private double FromBytes(double bytes, string unit) => bytes / Units[unit].Factor;

    public double Convert(double value, string fromUnit, string toUnit)
    {
        double bytes = ToBytes(value, fromUnit);
        double result = FromBytes(bytes, toUnit);
        history.Add($"{Format(value, fromUnit)} -> {Format(result, toUnit)}");
        if (history.Count > 20) history.RemoveAt(0);
        return result;
    }

    public (double value, string unit) AutoConvert(double value, string unit)
    {
        double bytes = ToBytes(value, unit);
        string[] order = { "b", "B", "KB", "KiB", "MB", "MiB", "GB", "GiB", "TB", "TiB", "PB", "PiB" };
        string bestUnit = "B";
        double bestVal = bytes;
        foreach (var u in order)
        {
            double v = bytes / Units[u].Factor;
            if (v >= 1 && v < 1000)
            {
                bestUnit = u;
                bestVal = v;
                break;
            }
        }
        if (bestUnit == "B" && bytes < 1)
        {
            bestUnit = "b";
            bestVal = bytes / Units["b"].Factor;
        }
        return (bestVal, bestUnit);
    }

    public string Format(double value, string unit) =>
        $"{value.ToString($"F{precision}")} {unit}";

    public void ShowHistory()
    {
        if (history.Count == 0)
        {
            Console.WriteLine("No conversions yet.");
            return;
        }
        Console.WriteLine("\n--- Conversion History (last 20) ---");
        for (int i = 0; i < history.Count; i++)
            Console.WriteLine($"{i+1}. {history[i]}");
    }

    public void PrintHelp()
    {
        Console.WriteLine("\nSupported units:");
        foreach (var kv in Units.OrderBy(kv => kv.Key))
            Console.WriteLine($"  {kv.Key,4} = {kv.Value.Name} (factor {kv.Value.Factor})");
    }

    static void Main()
    {
        var converter = new DataConverter(2);
        Console.WriteLine("=== Data Unit Converter ===");
        while (true)
        {
            Console.WriteLine("\n1. Convert single value");
            Console.WriteLine("2. Batch convert from file");
            Console.WriteLine("3. Show conversion history");
            Console.WriteLine($"4. Set precision (current: {converter.precision})");
            Console.WriteLine("5. Help / unit info");
            Console.WriteLine("6. Exit");
            Console.Write("Choose: ");
            string choice = Console.ReadLine()?.Trim() ?? "";
            switch (choice)
            {
                case "1":
                    try
                    {
                        Console.Write("Enter value and unit (e.g., 1024 MB): ");
                        string inp = Console.ReadLine();
                        var (val, fromUnit) = converter.ParseValueUnit(inp);
                        Console.Write("Target unit (leave blank for auto): ");
                        string target = Console.ReadLine()?.Trim() ?? "";
                        if (!string.IsNullOrEmpty(target))
                        {
                            string toUnit = null;
                            foreach (var u in Units.Keys)
                                if (string.Equals(u, target, StringComparison.OrdinalIgnoreCase))
                                { toUnit = u; break; }
                            if (toUnit == null)
                            {
                                Console.WriteLine("Unknown target unit.");
                                break;
                            }
                            double result = converter.Convert(val, fromUnit, toUnit);
                            Console.WriteLine($"\nResult: {converter.Format(val, fromUnit)} = {converter.Format(result, toUnit)}");
                        }
                        else
                        {
                            var (result, bestUnit) = converter.AutoConvert(val, fromUnit);
                            converter.history.Add($"{converter.Format(val, fromUnit)} -> {converter.Format(result, bestUnit)}");
                            if (converter.history.Count > 20) converter.history.RemoveAt(0);
                            Console.WriteLine($"\nResult: {converter.Format(val, fromUnit)} = {converter.Format(result, bestUnit)}");
                        }
                    }
                    catch (Exception e) { Console.WriteLine($"Error: {e.Message}"); }
                    break;
                case "2":
                    Console.Write("Enter batch file path: ");
                    string fname = Console.ReadLine()?.Trim() ?? "";
                    if (!File.Exists(fname))
                    {
                        Console.WriteLine("File not found.");
                        break;
                    }
                    Console.Write("Target unit for all conversions (leave blank for auto): ");
                    string target2 = Console.ReadLine()?.Trim() ?? "";
                    string toUnit2 = null;
                    if (!string.IsNullOrEmpty(target2))
                    {
                        foreach (var u in Units.Keys)
                            if (string.Equals(u, target2, StringComparison.OrdinalIgnoreCase))
                            { toUnit2 = u; break; }
                        if (toUnit2 == null)
                        {
                            Console.WriteLine("Unknown target unit.");
                            break;
                        }
                    }
                    Console.WriteLine("\nBatch results:");
                    foreach (var line in File.ReadLines(fname))
                    {
                        string l = line.Trim();
                        if (string.IsNullOrEmpty(l)) continue;
                        try
                        {
                            var (val, fromUnit) = converter.ParseValueUnit(l);
                            if (toUnit2 != null)
                            {
                                double result = converter.Convert(val, fromUnit, toUnit2);
                                Console.WriteLine($"{converter.Format(val, fromUnit)} -> {converter.Format(result, toUnit2)}");
                            }
                            else
                            {
                                var (result, bestUnit) = converter.AutoConvert(val, fromUnit);
                                Console.WriteLine($"{converter.Format(val, fromUnit)} -> {converter.Format(result, bestUnit)}");
                            }
                        }
                        catch (Exception e) { Console.WriteLine($"Skipping '{l}': {e.Message}"); }
                    }
                    break;
                case "3":
                    converter.ShowHistory();
                    break;
                case "4":
                    Console.Write("Enter number of decimal places: ");
                    if (int.TryParse(Console.ReadLine(), out int prec) && prec >= 0)
                    {
                        converter.precision = prec;
                        Console.WriteLine("Precision updated.");
                    }
                    else Console.WriteLine("Invalid precision.");
                    break;
                case "5":
                    converter.PrintHelp();
                    break;
                case "6":
                    Console.WriteLine("Goodbye!");
                    return;
                default:
                    Console.WriteLine("Invalid choice.");
                    break;
            }
        }
    }
}
