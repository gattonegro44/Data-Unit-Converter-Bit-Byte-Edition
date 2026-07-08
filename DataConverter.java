// DataConverter.java
import java.io.*;
import java.util.*;
import java.util.regex.*;

class UnitInfo {
    String name;
    double factor;
    UnitInfo(String n, double f) { name = n; factor = f; }
}

public class DataConverter {
    private static final Map<String, UnitInfo> UNITS = new LinkedHashMap<>();
    static {
        UNITS.put("b", new UnitInfo("bit", 1.0/8));
        UNITS.put("B", new UnitInfo("byte", 1));
        UNITS.put("KB", new UnitInfo("kilobyte", 1000));
        UNITS.put("KiB", new UnitInfo("kibibyte", 1024));
        UNITS.put("MB", new UnitInfo("megabyte", 1000*1000));
        UNITS.put("MiB", new UnitInfo("mebibyte", 1024*1024));
        UNITS.put("GB", new UnitInfo("gigabyte", 1000*1000*1000));
        UNITS.put("GiB", new UnitInfo("gibibyte", 1024*1024*1024));
        UNITS.put("TB", new UnitInfo("terabyte", 1000L*1000*1000*1000));
        UNITS.put("TiB", new UnitInfo("tebibyte", 1024L*1024*1024*1024));
        UNITS.put("PB", new UnitInfo("petabyte", 1000L*1000*1000*1000*1000));
        UNITS.put("PiB", new UnitInfo("pebibyte", 1024L*1024*1024*1024*1024));
    }
    private static final List<String> UNIT_ORDER = Arrays.asList("b","B","KB","KiB","MB","MiB","GB","GiB","TB","TiB","PB","PiB");

    private int precision;
    private List<String> history = new ArrayList<>();

    public DataConverter(int prec) { precision = prec; }

    private class Parsed {
        double value; String unit;
        Parsed(double v, String u) { value = v; unit = u; }
    }

    private Parsed parseValueUnit(String s) throws Exception {
        s = s.trim();
        Matcher m = Pattern.compile("^([\\d.]+)\\s*([a-zA-Z]+)$").matcher(s);
        if (!m.matches()) {
            try {
                double val = Double.parseDouble(s);
                return new Parsed(val, "B");
            } catch (NumberFormatException e) {
                throw new Exception("Invalid format. Use 'value unit'.");
            }
        }
        double val = Double.parseDouble(m.group(1));
        String unitStr = m.group(2).toUpperCase();
        String unit = null;
        for (String u : UNITS.keySet()) {
            if (u.equalsIgnoreCase(unitStr)) { unit = u; break; }
        }
        if (unit == null && unitStr.endsWith("B") && unitStr.length() > 1) {
            String shortU = unitStr.substring(0, unitStr.length()-1);
            for (String u : UNITS.keySet()) {
                if (u.equalsIgnoreCase(shortU)) { unit = u; break; }
            }
        }
        if (unit == null) throw new Exception("Unknown unit: " + unitStr);
        return new Parsed(val, unit);
    }

    private double toBytes(double value, String unit) { return value * UNITS.get(unit).factor; }
    private double fromBytes(double bytes, String unit) { return bytes / UNITS.get(unit).factor; }

    public double convert(double value, String fromUnit, String toUnit) {
        double bytes = toBytes(value, fromUnit);
        double result = fromBytes(bytes, toUnit);
        history.add(format(value, fromUnit) + " -> " + format(result, toUnit));
        if (history.size() > 20) history.remove(0);
        return result;
    }

    public Parsed autoConvert(double value, String unit) {
        double bytes = toBytes(value, unit);
        String bestUnit = "B";
        double bestVal = bytes;
        for (String u : UNIT_ORDER) {
            double v = bytes / UNITS.get(u).factor;
            if (v >= 1 && v < 1000) {
                bestUnit = u;
                bestVal = v;
                break;
            }
        }
        if (bestUnit.equals("B") && bytes < 1) {
            bestUnit = "b";
            bestVal = bytes / UNITS.get("b").factor;
        }
        return new Parsed(bestVal, bestUnit);
    }

    public String format(double value, String unit) {
        return String.format("%." + precision + "f %s", value, unit);
    }

    public void showHistory() {
        if (history.isEmpty()) {
            System.out.println("No conversions yet.");
        } else {
            System.out.println("\n--- Conversion History (last 20) ---");
            for (int i = 0; i < history.size(); i++) {
                System.out.println((i+1) + ". " + history.get(i));
            }
        }
    }

    public void printHelp() {
        System.out.println("\nSupported units:");
        for (Map.Entry<String, UnitInfo> e : UNITS.entrySet()) {
            System.out.printf("  %4s = %s (factor %.0f)\n", e.getKey(), e.getValue().name, e.getValue().factor);
        }
    }

    public static void main(String[] args) throws Exception {
        Scanner scanner = new Scanner(System.in);
        DataConverter converter = new DataConverter(2);
        System.out.println("=== Data Unit Converter ===");
        while (true) {
            System.out.println("\n1. Convert single value");
            System.out.println("2. Batch convert from file");
            System.out.println("3. Show conversion history");
            System.out.println("4. Set precision (current: " + converter.precision + ")");
            System.out.println("5. Help / unit info");
            System.out.println("6. Exit");
            System.out.print("Choose: ");
            String choice = scanner.nextLine().trim();
            switch (choice) {
                case "1":
                    try {
                        System.out.print("Enter value and unit (e.g., 1024 MB): ");
                        String inp = scanner.nextLine();
                        Parsed p = converter.parseValueUnit(inp);
                        System.out.print("Target unit (leave blank for auto): ");
                        String target = scanner.nextLine().trim();
                        if (!target.isEmpty()) {
                            String toUnit = null;
                            for (String u : UNITS.keySet()) {
                                if (u.equalsIgnoreCase(target)) { toUnit = u; break; }
                            }
                            if (toUnit == null) {
                                System.out.println("Unknown target unit.");
                                break;
                            }
                            double result = converter.convert(p.value, p.unit, toUnit);
                            System.out.println("\nResult: " + converter.format(p.value, p.unit) + " = " + converter.format(result, toUnit));
                        } else {
                            Parsed auto = converter.autoConvert(p.value, p.unit);
                            converter.history.add(converter.format(p.value, p.unit) + " -> " + converter.format(auto.value, auto.unit));
                            if (converter.history.size() > 20) converter.history.remove(0);
                            System.out.println("\nResult: " + converter.format(p.value, p.unit) + " = " + converter.format(auto.value, auto.unit));
                        }
                    } catch (Exception e) {
                        System.out.println("Error: " + e.getMessage());
                    }
                    break;
                case "2":
                    System.out.print("Enter batch file path: ");
                    String fname = scanner.nextLine().trim();
                    File file = new File(fname);
                    if (!file.exists()) {
                        System.out.println("File not found.");
                        break;
                    }
                    System.out.print("Target unit for all conversions (leave blank for auto): ");
                    String target2 = scanner.nextLine().trim();
                    String toUnit2 = null;
                    if (!target2.isEmpty()) {
                        for (String u : UNITS.keySet()) {
                            if (u.equalsIgnoreCase(target2)) { toUnit2 = u; break; }
                        }
                        if (toUnit2 == null) {
                            System.out.println("Unknown target unit.");
                            break;
                        }
                    }
                    System.out.println("\nBatch results:");
                    try (BufferedReader br = new BufferedReader(new FileReader(file))) {
                        String line;
                        while ((line = br.readLine()) != null) {
                            line = line.trim();
                            if (line.isEmpty()) continue;
                            try {
                                Parsed p2 = converter.parseValueUnit(line);
                                if (toUnit2 != null) {
                                    double result = converter.convert(p2.value, p2.unit, toUnit2);
                                    System.out.println(converter.format(p2.value, p2.unit) + " -> " + converter.format(result, toUnit2));
                                } else {
                                    Parsed auto2 = converter.autoConvert(p2.value, p2.unit);
                                    System.out.println(converter.format(p2.value, p2.unit) + " -> " + converter.format(auto2.value, auto2.unit));
                                }
                            } catch (Exception e) {
                                System.out.println("Skipping '" + line + "': " + e.getMessage());
                            }
                        }
                    }
                    break;
                case "3":
                    converter.showHistory();
                    break;
                case "4":
                    System.out.print("Enter number of decimal places: ");
                    try {
                        int prec = Integer.parseInt(scanner.nextLine().trim());
                        if (prec < 0) throw new NumberFormatException();
                        converter.precision = prec;
                        System.out.println("Precision updated.");
                    } catch (NumberFormatException e) {
                        System.out.println("Invalid precision.");
                    }
                    break;
                case "5":
                    converter.printHelp();
                    break;
                case "6":
                    System.out.println("Goodbye!");
                    scanner.close();
                    return;
                default:
                    System.out.println("Invalid choice.");
            }
        }
    }
}
