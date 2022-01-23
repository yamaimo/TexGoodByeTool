# OS/2テーブル

require_relative 'font_data_extension'

class Os2Table

  using FontDataExtension

  def self.from_file(file, os2_record, units)
    file.seek(os2_record.offset)

    # version(2byte), average_char_width(2byte)はスキップ
    file.seek(4, IO::SEEK_CUR)

    weight = file.read_uint16

    # width_class(2byte), embed_license_flag(2byte),
    # subscript関係(2byte x 4), supscript関係(2byte x 4),
    # strikeout関係(2byte x 2)はスキップ
    file.seek(24, IO::SEEK_CUR)

    family_class = file.read_int16 >> 8 # 上位8bitがクラスID

    # panose(10byte), unicode_range(16byte), vendor_id(4byte),
    # pattern_flag(2byte), first/last_char_Index(2byte x 2)は
    # スキップ
    file.seek(36, IO::SEEK_CUR)

    ascender = file.read_int16 * 1000 / units
    descender = file.read_int16 * 1000 / units
    line_gap = file.read_int16 * 1000 / units

    # win_ascender, win_descender, 他、残りは無視

    self.new(weight, family_class, ascender, descender, line_gap)
  end

  def initialize(weight, family_class, ascender, descender, line_gap)
    @weight = weight
    @family_class = family_class
    @ascender = ascender
    @descender = descender
    @line_gap = line_gap
  end

  attr_reader :weight, :family_class, :ascender, :descender, :line_gap

  def bold?
    @weight > 400 # Normal(Regular)は400
  end

  # family class id
  # 1: Oldstyle Serifs
  # 2: Transitional Serifs
  # 3: Modern Serifs
  # 4: Clarendon Serifs
  # 5: Slab Serifs
  # 6: (reserved)
  # 7: Freeform Serifs
  # 8: Sans Serif
  # 9: Ornamentals
  # 10: Scripts
  # 11: (reserved)
  # 12: Symbolic
  # 13: (reserved)
  # 14: (reserved)

  def serif?
    [1, 2, 3, 4, 5, 7].include?(@family_class)
  end

  def script?
    @family_class == 10
  end

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
    os2_table = Os2Table.from_file(file, table_directory.records['OS/2'], head_table.units)

    puts "weight      : #{os2_table.weight}"
    puts "family class: #{os2_table.family_class}"
    puts "ascender    : #{os2_table.ascender}"
    puts "descender   : #{os2_table.descender}"
    puts "line gap    : #{os2_table.line_gap}"
    puts "bold?       : #{os2_table.bold?}"
    puts "serif?      : #{os2_table.serif?}"
    puts "script?     : #{os2_table.script?}"
  end
end
