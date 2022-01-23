# hmtxテーブル

require_relative 'font_data_extension'

class HmtxTable

  using FontDataExtension

  def self.from_file(file, hmtx_record, hmetrics_count, units)
    file.seek(hmtx_record.offset)

    width_count = Hash.new(0)
    widths = hmetrics_count.times.map do
      width = file.read_uint16 * 1000 / units
      lsb = file.read_int16 # lsbは使わない
      width_count[width] += 1
      width
    end

    # 最頻値
    mode_width = width_count.max_by{|width, count| count}[0]

    self.new(widths, mode_width)
  end

  def initialize(widths, mode_width)
    @widths = widths
    @mode_width = mode_width
  end

  attr_reader :widths, :mode_width

end

if __FILE__ == $0
  require_relative 'table_directory'
  require_relative 'head_table'
  require_relative 'hhea_table'

  if ARGV.empty?
    raise "No font file is specified."
  end

  filename = ARGV[0]

  File.open(filename, 'rb') do |file|
    table_directory = TableDirectory.from_file(file)
    head_table = HeadTable.from_file(file, table_directory.records['head'])
    hhea_table = HheaTable.from_file(file, table_directory.records['hhea'], head_table.units)
    hmtx_table = HmtxTable.from_file(file, table_directory.records['hmtx'], hhea_table.hmetrics_count, head_table.units)

    puts "count: #{hmtx_table.widths.count}"
    puts "width: #{hmtx_table.widths[0..9].join(', ')}, ..."
    puts "mode : #{hmtx_table.mode_width}"
  end
end
