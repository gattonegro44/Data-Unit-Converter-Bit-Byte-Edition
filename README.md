# 🔢 Data Unit Converter – Bit & Byte Edition

A powerful, multi‑language **data size converter** that handles bits, bytes, and all common multiples (kilobytes, megabytes, gigabytes, terabytes, petabytes).  
Supports **both decimal (SI) and binary (IEC) prefixes** – convert seamlessly between `KB` and `KiB`, `MB` and `MiB`, etc.

## ✨ Features
- **Wide range of units** – bit (b), byte (B), kilobyte (KB / KiB), megabyte (MB / MiB), gigabyte (GB / GiB), terabyte (TB / TiB), petabyte (PB / PiB).
- **Dual system support** – choose decimal (×1000) or binary (×1024) for each conversion.
- **Interactive menu** – convert single values, batch convert from a file, or explore unit definitions.
- **Batch mode** – read multiple lines from a text file (each containing `value unit`), convert them all to a target unit.
- **Human‑readable output** – automatically select the best unit for large numbers (e.g., `2.5 GB` instead of `2500000000 B`).
- **Conversion history** – keep track of the last 20 conversions (display on demand).
- **Precision control** – set the number of decimal places (default 2).
- **Auto‑detection** – parse input like `1.5MB`, `2 GiB`, `1024` (assumes bytes if no unit given).

## 🗂 Languages & Files
| Language          | File                      |
|-------------------|---------------------------|
| Python            | `data_converter.py`       |
| Go                | `data_converter.go`       |
| C#                | `DataConverter.cs`        |
| JavaScript (Node) | `data_converter.js`       |
| Java              | `DataConverter.java`      |
| Ruby              | `data_converter.rb`       |
| Swift             | `data_converter.swift`    |

## 🚀 How to Run
Each file is standalone – run it with the appropriate interpreter/compiler:

| Language | Command |
|----------|---------|
| Python   | `python data_converter.py` |
| Go       | `go run data_converter.go` |
| C#       | `dotnet run` (or `csc DataConverter.cs`) |
| JavaScript | `node data_converter.js` |
| Java     | `javac DataConverter.java && java DataConverter` |
| Ruby     | `ruby data_converter.rb` |
| Swift    | `swift data_converter.swift` |

## 📊 Example Session
=== Data Unit Converter ===

Convert single value

Batch convert from file

Show conversion history

Set precision (current: 2 decimals)

Help / unit info

Exit
Choose: 1

Enter value and unit (e.g., 1024 MB): 1.5 GB
Target unit (e.g., MiB): MiB

Result: 1.50 GB = 1430.51 MiB
(Decimal: 1.50 GB = 1500.00 MB)

text

## 🔧 Supported Units
| Symbol | Name          | Base |
|--------|---------------|------|
| b      | bit           | 1    |
| B      | byte          | 8 b  |
| KB     | kilobyte      | 1000 B |
| KiB    | kibibyte      | 1024 B |
| MB     | megabyte      | 1000 KB|
| MiB    | mebibyte      | 1024 KiB|
| GB     | gigabyte      | 1000 MB|
| GiB    | gibibyte      | 1024 MiB|
| TB     | terabyte      | 1000 GB|
| TiB    | tebibyte      | 1024 GiB|
| PB     | petabyte      | 1000 TB|
| PiB    | pebibyte      | 1024 TiB|

## 📁 Batch File Format
A plain text file with one conversion per line:
1024 MB
2.5 GiB
5000000000 B

text
The converter will process each line and output results in the chosen target unit.

## 🤝 Contributing
Add more languages, support for exabytes, or a GUI – PRs are welcome!

## 📜 License
MIT – use anywhere.
