# data_converter.rb
UNITS = {
  'b'   => { name: 'bit', factor: 1.0/8 },
  'B'   => { name: 'byte', factor: 1 },
  'KB'  => { name: 'kilobyte', factor: 1000 },
  'KiB' => { name: 'kibibyte', factor: 1024 },
  'MB'  => { name: 'megabyte', factor: 1000**2 },
  'MiB' => { name: 'mebibyte', factor: 1024**2 },
  'GB'  => { name: 'gigabyte', factor: 1000**3 },
  'GiB' => { name: 'gibibyte', factor: 1024**3 },
  'TB'  => { name: 'terabyte', factor: 1000**4 },
  'TiB' => { name: 'tebibyte', factor: 1024**4 },
  'PB'  => { name: 'petabyte', factor: 1000**5 },
  'PiB' => { name: 'pebibyte', factor: 1024**5 }
}
UNIT_ORDER = %w[b B KB KiB MB MiB GB GiB TB TiB PB PiB]

class DataConverter
  attr_accessor :precision
  attr_reader :history

  def initialize(precision = 2)
    @precision = precision
    @history = []
  end

  def parse_value_unit(s)
    s = s.strip
    if s =~ /^([\d.]+)\s*([a-zA-Z]+)$/
      val = $1.to_f
      unit_str = $2.upcase
      unit = UNITS.keys.find { |u| u.casecmp(unit_str).zero? }
      if unit.nil? && unit_str.end_with?('B') && unit_str.length > 1
        short = unit_str[0...-1]
        unit = UNITS.keys.find { |u| u.casecmp(short).zero? }
      end
      raise "Unknown unit: #{unit_str}" if unit.nil?
      return { value: val, unit: unit }
    else
      val = Float(s) rescue nil
      return { value: val, unit: 'B' } if val
      raise "Invalid format. Use 'value unit'."
    end
  end

  def to_bytes(value, unit)
    value * UNITS[unit][:factor]
  end

  def from_bytes(bytes, unit)
    bytes / UNITS[unit][:factor]
  end

  def convert(value, from_unit, to_unit)
    bytes = to_bytes(value, from_unit)
    result = from_bytes(bytes, to_unit)
    @history << "#{format(value, from_unit)} -> #{format(result, to_unit)}"
    @history.shift if @history.size > 20
    result
  end

  def auto_convert(value, unit)
    bytes = to_bytes(value, unit)
    best_unit = 'B'
    best_val = bytes
    UNIT_ORDER.each do |u|
      v = bytes / UNITS[u][:factor]
      if v >= 1 && v < 1000
        best_unit = u
        best_val = v
        break
      end
    end
    if best_unit == 'B' && bytes < 1
      best_unit = 'b'
      best_val = bytes / UNITS['b'][:factor]
    end
    { value: best_val, unit: best_unit }
  end

  def format(value, unit)
    format("%.#{@precision}f %s", value, unit)
  end

  def show_history
    if @history.empty?
      puts "No conversions yet."
    else
      puts "\n--- Conversion History (last 20) ---"
      @history.each_with_index { |h, i| puts "#{i+1}. #{h}" }
    end
  end

  def print_help
    puts "\nSupported units:"
    UNITS.sort.each do |u, info|
      puts "  %4s = %s (factor %.0f)" % [u, info[:name], info[:factor]]
    end
  end
end

def main
  converter = DataConverter.new(2)
  puts "=== Data Unit Converter ==="
  loop do
    puts "\n1. Convert single value"
    puts "2. Batch convert from file"
    puts "3. Show conversion history"
    puts "4. Set precision (current: #{converter.precision})"
    puts "5. Help / unit info"
    puts "6. Exit"
    print "Choose: "
    choice = gets.chomp.strip
    case choice
    when '1'
      begin
        print "Enter value and unit (e.g., 1024 MB): "
        inp = gets.chomp
        parsed = converter.parse_value_unit(inp)
        print "Target unit (leave blank for auto): "
        target = gets.chomp.strip
        if !target.empty?
          to_unit = UNITS.keys.find { |u| u.casecmp(target).zero? }
          if to_unit.nil?
            puts "Unknown target unit."
            next
          end
          result = converter.convert(parsed[:value], parsed[:unit], to_unit)
          puts "\nResult: #{converter.format(parsed[:value], parsed[:unit])} = #{converter.format(result, to_unit)}"
        else
          auto = converter.auto_convert(parsed[:value], parsed[:unit])
          converter.history << "#{converter.format(parsed[:value], parsed[:unit])} -> #{converter.format(auto[:value], auto[:unit])}"
          converter.history.shift if converter.history.size > 20
          puts "\nResult: #{converter.format(parsed[:value], parsed[:unit])} = #{converter.format(auto[:value], auto[:unit])}"
        end
      rescue => e
        puts "Error: #{e.message}"
      end
    when '2'
      print "Enter batch file path: "
      fname = gets.chomp.strip
      unless File.exist?(fname)
        puts "File not found."
        next
      end
      print "Target unit for all conversions (leave blank for auto): "
      target2 = gets.chomp.strip
      to_unit2 = nil
      if !target2.empty?
        to_unit2 = UNITS.keys.find { |u| u.casecmp(target2).zero? }
        if to_unit2.nil?
          puts "Unknown target unit."
          next
        end
      end
      puts "\nBatch results:"
      File.readlines(fname).each do |line|
        line = line.strip
        next if line.empty?
        begin
          parsed2 = converter.parse_value_unit(line)
          if to_unit2
            result2 = converter.convert(parsed2[:value], parsed2[:unit], to_unit2)
            puts "#{converter.format(parsed2[:value], parsed2[:unit])} -> #{converter.format(result2, to_unit2)}"
          else
            auto2 = converter.auto_convert(parsed2[:value], parsed2[:unit])
            puts "#{converter.format(parsed2[:value], parsed2[:unit])} -> #{converter.format(auto2[:value], auto2[:unit])}"
          end
        rescue => e
          puts "Skipping '#{line}': #{e.message}"
        end
      end
    when '3'
      converter.show_history
    when '4'
      print "Enter number of decimal places: "
      prec = gets.chomp.to_i
      if prec >= 0
        converter.precision = prec
        puts "Precision updated."
      else
        puts "Invalid precision."
      end
    when '5'
      converter.print_help
    when '6'
      puts "Goodbye!"
      break
    else
      puts "Invalid choice."
    end
  end
end

main if __FILE__ == $0
