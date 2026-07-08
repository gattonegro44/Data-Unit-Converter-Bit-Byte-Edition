// data_converter.go
package main

import (
	"bufio"
	"fmt"
	"math"
	"os"
	"strconv"
	"strings"
)

type UnitInfo struct {
	Name   string
	Factor float64
}

var units = map[string]UnitInfo{
	"b":   {"bit", 1.0 / 8},
	"B":   {"byte", 1},
	"KB":  {"kilobyte", 1000},
	"KiB": {"kibibyte", 1024},
	"MB":  {"megabyte", 1000 * 1000},
	"MiB": {"mebibyte", 1024 * 1024},
	"GB":  {"gigabyte", 1000 * 1000 * 1000},
	"GiB": {"gibibyte", 1024 * 1024 * 1024},
	"TB":  {"terabyte", 1000 * 1000 * 1000 * 1000},
	"TiB": {"tebibyte", 1024 * 1024 * 1024 * 1024},
	"PB":  {"petabyte", 1000 * 1000 * 1000 * 1000 * 1000},
	"PiB": {"pebibyte", 1024 * 1024 * 1024 * 1024 * 1024},
}

type Converter struct {
	precision int
	history   []string
}

func NewConverter(prec int) *Converter {
	return &Converter{precision: prec, history: []string{}}
}

func (c *Converter) parseValueUnit(s string) (float64, string, error) {
	s = strings.TrimSpace(s)
	// split last word as unit
	parts := strings.Fields(s)
	if len(parts) == 1 {
		// only number, assume bytes
		val, err := strconv.ParseFloat(parts[0], 64)
		if err != nil {
			return 0, "", err
		}
		return val, "B", nil
	}
	// join all but last as value
	valStr := strings.Join(parts[:len(parts)-1], " ")
	unitStr := strings.ToUpper(parts[len(parts)-1])
	val, err := strconv.ParseFloat(valStr, 64)
	if err != nil {
		return 0, "", err
	}
	// normalize unit
	for u := range units {
		if strings.EqualFold(u, unitStr) {
			return val, u, nil
		}
	}
	// try alias: if unit ends with 'b' and not in map, try without 'b' etc.
	if strings.HasSuffix(unitStr, "B") && len(unitStr) > 1 {
		short := unitStr[:len(unitStr)-1]
		for u := range units {
			if strings.EqualFold(u, short) {
				return val, u, nil
			}
		}
	}
	return 0, "", fmt.Errorf("unknown unit: %s", unitStr)
}

func (c *Converter) toBytes(value float64, unit string) float64 {
	return value * units[unit].Factor
}

func (c *Converter) fromBytes(bytesVal float64, unit string) float64 {
	return bytesVal / units[unit].Factor
}

func (c *Converter) convert(value float64, fromUnit, toUnit string) float64 {
	bytesVal := c.toBytes(value, fromUnit)
	return c.fromBytes(bytesVal, toUnit)
}

func (c *Converter) autoConvert(value float64, unit string) (float64, string) {
	bytesVal := c.toBytes(value, unit)
	bestUnit := "B"
	bestVal := bytesVal
	// iterate units in order of size (smallest to largest)
	order := []string{"b", "B", "KB", "KiB", "MB", "MiB", "GB", "GiB", "TB", "TiB", "PB", "PiB"}
	for _, u := range order {
		f := units[u].Factor
		v := bytesVal / f
		if v >= 1 && v < 1000 {
			bestUnit = u
			bestVal = v
			break
		}
	}
	// if all <1, use bits
	if bestUnit == "B" && bytesVal < 1 {
		bestUnit = "b"
		bestVal = bytesVal / units["b"].Factor
	}
	return bestVal, bestUnit
}

func (c *Converter) format(val float64, unit string) string {
	return fmt.Sprintf("%.*f %s", c.precision, val, unit)
}

func (c *Converter) addHistory(value float64, fromUnit string, result float64, toUnit string) {
	c.history = append(c.history, fmt.Sprintf("%s %s -> %s %s", c.format(value, fromUnit), fromUnit, c.format(result, toUnit), toUnit))
	if len(c.history) > 20 {
		c.history = c.history[1:]
	}
}

func (c *Converter) showHistory() {
	if len(c.history) == 0 {
		fmt.Println("No conversions yet.")
		return
	}
	fmt.Println("\n--- Conversion History (last 20) ---")
	for i, h := range c.history {
		fmt.Printf("%d. %s\n", i+1, h)
	}
}

func main() {
	converter := NewConverter(2)
	scanner := bufio.NewScanner(os.Stdin)
	fmt.Println("=== Data Unit Converter ===")
	for {
		fmt.Println("\n1. Convert single value")
		fmt.Println("2. Batch convert from file")
		fmt.Println("3. Show conversion history")
		fmt.Println("4. Set precision (current:", converter.precision, ")")
		fmt.Println("5. Help / unit info")
		fmt.Println("6. Exit")
		fmt.Print("Choose: ")
		scanner.Scan()
		choice := strings.TrimSpace(scanner.Text())
		switch choice {
		case "1":
			fmt.Print("Enter value and unit (e.g., 1024 MB): ")
			scanner.Scan()
			inp := scanner.Text()
			val, fromUnit, err := converter.parseValueUnit(inp)
			if err != nil {
				fmt.Println("Error:", err)
				continue
			}
			fmt.Print("Target unit (leave blank for auto): ")
			scanner.Scan()
			target := strings.TrimSpace(scanner.Text())
			if target != "" {
				toUnit := ""
				for u := range units {
					if strings.EqualFold(u, target) {
						toUnit = u
						break
					}
				}
				if toUnit == "" {
					fmt.Println("Unknown target unit.")
					continue
				}
				result := converter.convert(val, fromUnit, toUnit)
				converter.addHistory(val, fromUnit, result, toUnit)
				fmt.Printf("\nResult: %s = %s\n", converter.format(val, fromUnit), converter.format(result, toUnit))
			} else {
				result, bestUnit := converter.autoConvert(val, fromUnit)
				converter.addHistory(val, fromUnit, result, bestUnit)
				fmt.Printf("\nResult: %s = %s\n", converter.format(val, fromUnit), converter.format(result, bestUnit))
			}
		case "2":
			fmt.Print("Enter batch file path: ")
			scanner.Scan()
			fname := scanner.Text()
			file, err := os.Open(fname)
			if err != nil {
				fmt.Println("Error:", err)
				continue
			}
			defer file.Close()
			fmt.Print("Target unit for all conversions (leave blank for auto): ")
			scanner.Scan()
			target := strings.TrimSpace(scanner.Text())
			toUnit := ""
			if target != "" {
				for u := range units {
					if strings.EqualFold(u, target) {
						toUnit = u
						break
					}
				}
				if toUnit == "" {
					fmt.Println("Unknown target unit.")
					continue
				}
			}
			fileScanner := bufio.NewScanner(file)
			fmt.Println("\nBatch results:")
			for fileScanner.Scan() {
				line := strings.TrimSpace(fileScanner.Text())
				if line == "" {
					continue
				}
				val, fromUnit, err := converter.parseValueUnit(line)
				if err != nil {
					fmt.Printf("Skipping '%s': %v\n", line, err)
					continue
				}
				if toUnit != "" {
					result := converter.convert(val, fromUnit, toUnit)
					fmt.Printf("%s -> %s\n", converter.format(val, fromUnit), converter.format(result, toUnit))
				} else {
					result, bestUnit := converter.autoConvert(val, fromUnit)
					fmt.Printf("%s -> %s\n", converter.format(val, fromUnit), converter.format(result, bestUnit))
				}
			}
		case "3":
			converter.showHistory()
		case "4":
			fmt.Print("Enter number of decimal places: ")
			scanner.Scan()
			prec, err := strconv.Atoi(strings.TrimSpace(scanner.Text()))
			if err != nil || prec < 0 {
				fmt.Println("Invalid precision.")
			} else {
				converter.precision = prec
				fmt.Println("Precision updated.")
			}
		case "5":
			fmt.Println("\nSupported units:")
			for u, info := range units {
				fmt.Printf("  %4s = %s (factor %.0f)\n", u, info.Name, info.Factor)
			}
		case "6":
			fmt.Println("Goodbye!")
			return
		default:
			fmt.Println("Invalid choice.")
		}
	}
}
