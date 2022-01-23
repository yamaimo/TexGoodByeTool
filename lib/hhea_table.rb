# hheaテーブル

require_relative 'font_data_extension'

class HheaTable

  using FontDataExtension

  def self.from_file(file, hhea_record, units)
    file.seek(hhea_record.offset)

    # major_version(2byte), minor_version(2byte)はスキップ
    file.seek(4, IO::SEEK_CUR)

    ascender = file.read_fword * 1000 / units
    descender = file.read_fword * 1000 / units
    line_gap = file.read_fword * 1000 / units

    # advance_width_max(2byte), min_left_side_bearing(2byte),
    # min_right_side_bearing(2byte), x_max_extent(2byte),
    # caret_slope_rise(2byte), caret_slope_run(2byte),
    # caret_offset(2byte), reserved(2byte x 4),
    # metric_data_format(2byte)はスキップ
    file.seek(24, IO::SEEK_CUR)

    hmetrics_count = file.read_uint16

    self.new(ascender, descender, line_gap, hmetrics_count)
  end

  def initialize(ascender, descender, line_gap, hmetrics_count)
    @ascender = ascender
    @descender = descender
    @line_gap = line_gap
    @hmetrics_count = hmetrics_count
  end

  attr_reader :ascender, :descender, :line_gap, :hmetrics_count

end

if __FILE__ == $0
  require_relative 'table_directory'
  require_relative 'head_table'

  if ARGV.empty?
    raise "No font file is specified."
  end

  filename = ARGV[0]

  File.open(filename, 'rb') do |file|
    table_directory = TableDirectory.from_file(file)
    head_table = HeadTable.from_file(file, table_directory.records['head'])
    hhea_table = HheaTable.from_file(file, table_directory.records['hhea'], head_table.units)

    puts "ascender      : #{hhea_table.ascender}"
    puts "descender     : #{hhea_table.descender}"
    puts "line gap      : #{hhea_table.line_gap}"
    puts "hmetrics count: #{hhea_table.hmetrics_count}"
  end
end
