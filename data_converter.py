# data_converter.py
import re
import math
from collections import deque

# Unit definitions: (name, base_bytes, aliases)
UNITS = {
    'b':   ('bit', 1/8),
    'B':   ('byte', 1),
    'KB':  ('kilobyte', 1000),
    'KiB': ('kibibyte', 1024),
    'MB':  ('megabyte', 1000**2),
    'MiB': ('mebibyte', 1024**2),
    'GB':  ('gigabyte', 1000**3),
    'GiB': ('gibibyte', 1024**3),
    'TB':  ('terabyte', 1000**4),
    'TiB': ('tebibyte', 1024**4),
    'PB':  ('petabyte', 1000**5),
    'PiB': ('pebibyte', 1024**5),
}
UNIT_ALIASES = {u.lower(): u for u in UNITS}
for u in UNITS:
    UNIT_ALIASES[u.lower()] = u
    # add common aliases
    if u.endswith('B') and not u.startswith('b'):
        UNIT_ALIASES[u[:-1].lower()] = u  # e.g., 'kb' -> 'KB'

class DataConverter:
    def __init__(self, precision=2):
        self.precision = precision
        self.history = deque(maxlen=20)

    def parse_value_unit(self, s):
        """Parse string like '1.5 MB' or '2GiB' into (value, unit)."""
        s = s.strip()
        # match number and unit
        m = re.match(r'^([\d.]+)\s*([a-zA-Z]+)$', s)
        if not m:
            # try just number -> assume bytes
            try:
                val = float(s)
                return val, 'B'
            except:
                raise ValueError("Invalid format. Use 'value unit' (e.g., 1.5 MB).")
        val = float(m.group(1))
        unit_str = m.group(2).strip()
        unit = UNIT_ALIASES.get(unit_str.lower())
        if not unit:
            raise ValueError(f"Unknown unit: {unit_str}")
        return val, unit

    def to_bytes(self, value, unit):
        return value * UNITS[unit][1]

    def from_bytes(self, bytes_val, unit):
        return bytes_val / UNITS[unit][1]

    def convert(self, value, from_unit, to_unit):
        bytes_val = self.to_bytes(value, from_unit)
        result = self.from_bytes(bytes_val, to_unit)
        self.history.append((value, from_unit, result, to_unit))
        return result

    def auto_convert(self, value, unit, target_unit=None):
        """Convert, if target_unit is None, choose best human-readable unit."""
        bytes_val = self.to_bytes(value, unit)
        if target_unit:
            return self.from_bytes(bytes_val, target_unit), target_unit
        else:
            # find best unit: choose the one with value between 1 and 1000 (or 1024)
            best_unit = 'B'
            best_val = bytes_val
            for u, (name, factor) in UNITS.items():
                v = bytes_val / factor
                if 1 <= v < 1000:
                    best_unit = u
                    best_val = v
                    break
            # if all <1, pick smallest unit
            if best_unit == 'B' and bytes_val < 1:
                best_unit = 'b'
                best_val = bytes_val / UNITS['b'][1]
            return best_val, best_unit

    def format_result(self, val, unit, precision=None):
        if precision is None:
            precision = self.precision
        return f"{val:.{precision}f} {unit}"

    def add_history_line(self, line):
        self.history.append(line)

    def show_history(self):
        if not self.history:
            print("No conversions yet.")
        else:
            print("\n--- Conversion History (last 20) ---")
            for i, (v, fu, r, tu) in enumerate(self.history, 1):
                print(f"{i}. {v} {fu} -> {self.format_result(r, tu)}")

def main():
    converter = DataConverter(precision=2)
    print("=== Data Unit Converter ===")
    while True:
        print("\n1. Convert single value")
        print("2. Batch convert from file")
        print("3. Show conversion history")
        print("4. Set precision (current: {})".format(converter.precision))
        print("5. Help / unit info")
        print("6. Exit")
        choice = input("Choose: ").strip()
        if choice == '1':
            try:
                inp = input("Enter value and unit (e.g., 1024 MB): ")
                val, from_unit = converter.parse_value_unit(inp)
                target = input("Target unit (leave blank for auto): ").strip()
                if target:
                    target_unit = UNIT_ALIASES.get(target.lower())
                    if not target_unit:
                        print("Unknown target unit.")
                        continue
                    result = converter.convert(val, from_unit, target_unit)
                    print(f"\nResult: {converter.format_result(val, from_unit)} = {converter.format_result(result, target_unit)}")
                else:
                    result, best_unit = converter.auto_convert(val, from_unit)
                    print(f"\nResult: {converter.format_result(val, from_unit)} = {converter.format_result(result, best_unit)}")
            except Exception as e:
                print(f"Error: {e}")
        elif choice == '2':
            fname = input("Enter batch file path: ").strip()
            try:
                with open(fname, 'r') as f:
                    lines = f.readlines()
                target = input("Target unit for all conversions (leave blank for auto): ").strip()
                if target:
                    target_unit = UNIT_ALIASES.get(target.lower())
                    if not target_unit:
                        print("Unknown target unit.")
                        continue
                print("\nBatch results:")
                for line in lines:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        val, from_unit = converter.parse_value_unit(line)
                        if target:
                            result = converter.convert(val, from_unit, target_unit)
                            print(f"{converter.format_result(val, from_unit)} -> {converter.format_result(result, target_unit)}")
                        else:
                            result, best_unit = converter.auto_convert(val, from_unit)
                            print(f"{converter.format_result(val, from_unit)} -> {converter.format_result(result, best_unit)}")
                    except Exception as e:
                        print(f"Skipping '{line}': {e}")
            except FileNotFoundError:
                print("File not found.")
        elif choice == '3':
            converter.show_history()
        elif choice == '4':
            try:
                prec = int(input("Enter number of decimal places: "))
                if prec < 0:
                    raise ValueError
                converter.precision = prec
                print("Precision updated.")
            except:
                print("Invalid precision.")
        elif choice == '5':
            print("\nSupported units:")
            for u, (name, factor) in sorted(UNITS.items()):
                print(f"  {u:4} = {name} (factor {factor})")
        elif choice == '6':
            print("Goodbye!")
            break
        else:
            print("Invalid choice.")

if __name__ == "__main__":
    main()
