# headテーブル

require_relative 'font_data_extension'

class HeadTable

  using FontDataExtension

  def self.from_file(file, head_record)
    file.seek(head_record.offset)

    # major_version(2byte), minor_version(2byte),
    # font_version(4byte), checksum(4byte),
    # magic_number(4byte), flags(2byte)はスキップ
    file.seek(18, IO::SEEK_CUR)

    units = file.read_uint16

    # created(8byte), modified(8byte)はスキップ
    file.seek(16, IO::SEEK_CUR)

    bound_box = 4.times.map { file.read_int16 * 1000 / units }

    # mac_style(2byte), lowest_rec_ppem(2byte),
    # font_direction_hint(2byte), index_to_loc_format(2byte),
    # glyph_data_format(2byte)は無視

    self.new(units, bound_box)
  end

  def initialize(units, bound_box)
    @units = units
    @bound_box = bound_box
  end

  attr_reader :units, :bound_box

end

if __FILE__ == $0
  require_relative 'table_directory'

  if ARGV.empty?
    raise "No font file is specified."
  end

  filename = ARGV[0]

  File.open(filename, 'rb') do |file|
    table_directory = TableDirectory.from_file(file)
    head_table = HeadTable.from_file(file, table_directory.records['head'])

    puts "units: #{head_table.units}"
    puts "bound box: #{head_table.bound_box}"
  end
end
