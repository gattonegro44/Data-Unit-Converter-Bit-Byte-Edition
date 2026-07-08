// data_converter.js
const readline = require('readline');
const fs = require('fs');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

const UNITS = {
    'b':   { name: 'bit', factor: 1/8 },
    'B':   { name: 'byte', factor: 1 },
    'KB':  { name: 'kilobyte', factor: 1000 },
    'KiB': { name: 'kibibyte', factor: 1024 },
    'MB':  { name: 'megabyte', factor: 1000*1000 },
    'MiB': { name: 'mebibyte', factor: 1024*1024 },
    'GB':  { name: 'gigabyte', factor: 1000*1000*1000 },
    'GiB': { name: 'gibibyte', factor: 1024*1024*1024 },
    'TB':  { name: 'terabyte', factor: 1000*1000*1000*1000 },
    'TiB': { name: 'tebibyte', factor: 1024*1024*1024*1024 },
    'PB':  { name: 'petabyte', factor: 1000*1000*1000*1000*1000 },
    'PiB': { name: 'pebibyte', factor: 1024*1024*1024*1024*1024 }
};

const UNIT_ORDER = ['b','B','KB','KiB','MB','MiB','GB','GiB','TB','TiB','PB','PiB'];

function ask(question) {
    return new Promise(resolve => rl.question(question, resolve));
}

class DataConverter {
    constructor(precision = 2) {
        this.precision = precision;
        this.history = [];
    }

    parseValueUnit(s) {
        s = s.trim();
        const m = s.match(/^([\d.]+)\s*([a-zA-Z]+)$/);
        if (!m) {
            const val = parseFloat(s);
            if (!isNaN(val)) return { value: val, unit: 'B' };
            throw new Error("Invalid format. Use 'value unit'.");
        }
        let val = parseFloat(m[1]);
        let unitStr = m[2].toUpperCase();
        // find unit
        let unit = null;
        for (let u of Object.keys(UNITS)) {
            if (u.toUpperCase() === unitStr) { unit = u; break; }
        }
        if (!unit) {
            // try alias: remove trailing B
            if (unitStr.endsWith('B') && unitStr.length > 1) {
                let short = unitStr.slice(0, -1);
                for (let u of Object.keys(UNITS)) {
                    if (u.toUpperCase() === short) { unit = u; break; }
                }
            }
        }
        if (!unit) throw new Error(`Unknown unit: ${unitStr}`);
        return { value: val, unit };
    }

    toBytes(value, unit) { return value * UNITS[unit].factor; }
    fromBytes(bytes, unit) { return bytes / UNITS[unit].factor; }

    convert(value, fromUnit, toUnit) {
        const bytes = this.toBytes(value, fromUnit);
        const result = this.fromBytes(bytes, toUnit);
        this.history.push(`${this.format(value, fromUnit)} -> ${this.format(result, toUnit)}`);
        if (this.history.length > 20) this.history.shift();
        return result;
    }

    autoConvert(value, unit) {
        const bytes = this.toBytes(value, unit);
        let bestUnit = 'B';
        let bestVal = bytes;
        for (let u of UNIT_ORDER) {
            let v = bytes / UNITS[u].factor;
            if (v >= 1 && v < 1000) {
                bestUnit = u;
                bestVal = v;
                break;
            }
        }
        if (bestUnit === 'B' && bytes < 1) {
            bestUnit = 'b';
            bestVal = bytes / UNITS['b'].factor;
        }
        return { value: bestVal, unit: bestUnit };
    }

    format(value, unit) {
        return `${value.toFixed(this.precision)} ${unit}`;
    }

    showHistory() {
        if (this.history.length === 0) {
            console.log("No conversions yet.");
        } else {
            console.log("\n--- Conversion History (last 20) ---");
            this.history.forEach((h, i) => console.log(`${i+1}. ${h}`));
        }
    }

    printHelp() {
        console.log("\nSupported units:");
        for (let [u, info] of Object.entries(UNITS).sort()) {
            console.log(`  ${u.padEnd(4)} = ${info.name} (factor ${info.factor})`);
        }
    }
}

async function main() {
    const converter = new DataConverter(2);
    console.log("=== Data Unit Converter ===");
    while (true) {
        console.log("\n1. Convert single value");
        console.log("2. Batch convert from file");
        console.log("3. Show conversion history");
        console.log(`4. Set precision (current: ${converter.precision})`);
        console.log("5. Help / unit info");
        console.log("6. Exit");
        const choice = await ask("Choose: ");
        switch (choice.trim()) {
            case '1': {
                try {
                    const inp = await ask("Enter value and unit (e.g., 1024 MB): ");
                    const { value: val, unit: fromUnit } = converter.parseValueUnit(inp);
                    const target = await ask("Target unit (leave blank for auto): ");
                    const targetTrim = target.trim();
                    if (targetTrim) {
                        let toUnit = null;
                        for (let u of Object.keys(UNITS)) {
                            if (u.toUpperCase() === targetTrim.toUpperCase()) { toUnit = u; break; }
                        }
                        if (!toUnit) {
                            console.log("Unknown target unit.");
                            break;
                        }
                        const result = converter.convert(val, fromUnit, toUnit);
                        console.log(`\nResult: ${converter.format(val, fromUnit)} = ${converter.format(result, toUnit)}`);
                    } else {
                        const { value: result, unit: bestUnit } = converter.autoConvert(val, fromUnit);
                        converter.history.push(`${converter.format(val, fromUnit)} -> ${converter.format(result, bestUnit)}`);
                        if (converter.history.length > 20) converter.history.shift();
                        console.log(`\nResult: ${converter.format(val, fromUnit)} = ${converter.format(result, bestUnit)}`);
                    }
                } catch (e) {
                    console.log(`Error: ${e.message}`);
                }
                break;
            }
            case '2': {
                const fname = await ask("Enter batch file path: ");
                if (!fs.existsSync(fname)) {
                    console.log("File not found.");
                    break;
                }
                const target2 = await ask("Target unit for all conversions (leave blank for auto): ");
                let toUnit2 = null;
                if (target2.trim()) {
                    for (let u of Object.keys(UNITS)) {
                        if (u.toUpperCase() === target2.trim().toUpperCase()) { toUnit2 = u; break; }
                    }
                    if (!toUnit2) {
                        console.log("Unknown target unit.");
                        break;
                    }
                }
                const lines = fs.readFileSync(fname, 'utf8').split('\n');
                console.log("\nBatch results:");
                for (let line of lines) {
                    line = line.trim();
                    if (!line) continue;
                    try {
                        const { value: val, unit: fromUnit } = converter.parseValueUnit(line);
                        if (toUnit2) {
                            const result = converter.convert(val, fromUnit, toUnit2);
                            console.log(`${converter.format(val, fromUnit)} -> ${converter.format(result, toUnit2)}`);
                        } else {
                            const { value: result, unit: bestUnit } = converter.autoConvert(val, fromUnit);
                            console.log(`${converter.format(val, fromUnit)} -> ${converter.format(result, bestUnit)}`);
                        }
                    } catch (e) {
                        console.log(`Skipping '${line}': ${e.message}`);
                    }
                }
                break;
            }
            case '3':
                converter.showHistory();
                break;
            case '4': {
                const prec = parseInt(await ask("Enter number of decimal places: "));
                if (isNaN(prec) || prec < 0) {
                    console.log("Invalid precision.");
                } else {
                    converter.precision = prec;
                    console.log("Precision updated.");
                }
                break;
            }
            case '5':
                converter.printHelp();
                break;
            case '6':
                console.log("Goodbye!");
                rl.close();
                return;
            default:
                console.log("Invalid choice.");
        }
    }
}

main().catch(console.error);
