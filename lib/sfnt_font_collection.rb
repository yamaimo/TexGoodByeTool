# SFNT形式フォントコレクション（TrueType, OpenType）

require 'pathname'

require_relative 'extname_extension'
require_relative 'sfnt_font'
require_relative 'ttc_header'
require_relative 'table_directory'

class SfntFontCollection < SfntFont

  using ExtnameExtension

  def self.extnames
    ['.ttc', '.otc']
  end

  def self.list_collection(filename)
    path = self.find_path(filename)
    ttc_header = path.open do |file|
      TtcHeader.from_file(file)
    end
    ttc_header.records.map(&:name)
  end

  def self.load(filename, index)
    path = self.find_path(filename)
    path.open do |file|
      ttc_header = TtcHeader.from_file(file)
      table_directory = TableDirectory.from_file(file, ttc_header.records[index].offset)
      head, name, post, os2, cmap, hhea, hmtx = self.load_tables(file, table_directory)
      self.new(path, index, table_directory.type, head, name, post, os2, cmap, hhea, hmtx)
    end
  end

  def initialize(path, index, type, head, name, post, os2, cmap, hhea, hmtx)
    super(path, type, head, name, post, os2, cmap, hhea, hmtx)
    @index = index
  end

  attr_reader :index

  def to_stream
    stream = File.open(@path, 'rb') do |file|
      ttc_header = TtcHeader.from_file(file)
      table_directory = TableDirectory.from_file(file, ttc_header.records[@index].offset)

      file.seek(ttc_header.records[@index].offset)

      # version(4byte), num_tables(2byte), search_range(2byte),
      # entry_selector(2byte), range_shift(2byte)はコピー
      stream = file.read(12)

      # 新しいオフセットは上記12バイトと各レコード(16byte)の後ろから
      new_offset = 12 + 16 * table_directory.records.size

      table_directory.records.each_value do |record|
        stream += record.tag
        stream += uint32_to_stream(record.checksum)
        stream += uint32_to_stream(new_offset)
        stream += uint32_to_stream(record.length)

        new_offset += aligned_length(record.length)
      end

      table_directory.records.each_value do |record|
        file.seek(record.offset)
        stream += file.read(aligned_length(record.length))
      end

      stream
    end
    stream
  end

  private

  def uint32_to_stream(num)
    [num].pack('N')
  end

  def aligned_length(table_length)
    # テーブルの長さと0埋めの長さは以下の関係：
    #   テーブルの長さ: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, ...
    #   0埋めの長さ   : 0, 3, 2, 1, 0, 3, 2, 1, 0, 3,  2, ...
    # よって0埋めの長さは以下で求まる：
    padding_length = (- table_length) % 4
    table_length + padding_length
  end

end

if __FILE__ == $0
  if ARGV.empty?
    puts "[Font collection file list] ----------"
    SfntFontCollection.list.each do |filename|
      puts filename
      SfntFontCollection.list_collection(filename).each_with_index do |name, i|
        puts "[#{i}] #{name}"
      end
    end
    puts "---------------------------"
    raise "No font collection file is specified."
  end

  filename = ARGV[0]

  if ARGV.size < 2
    puts "[Font collection list] ----------"
    SfntFontCollection.list_collection(filename).each_with_index do |name, i|
      puts "[#{i}] #{name}"
    end
    puts "---------------------------"
    raise "No font collection is specified."
  end

  index = ARGV[1].to_i

  font = SfntFontCollection.load(filename, index)
  puts "path : #{font.path}"
  puts "index: #{font.index}"
  puts "type : #{font.type}"
  puts "name : #{font.name}"
  puts "bound box : #{font.bound_box}"
  puts "mode width: #{font.mode_width}"
  puts "ascender  : #{font.ascender}"
  puts "descender : #{font.descender}"
  puts "line gap  : #{font.line_gap}"
  puts "weight    : #{font.weight}"
  puts "angle     : #{font.italic_angle}"
  puts "fixed pitch: #{font.fixed_pitch?}"
  puts "bold       : #{font.bold?}"
  puts "italic     : #{font.italic?}"
  puts "serif      : #{font.serif?}"
  puts "script     : #{font.script?}"

  ["ABCDE", "あいうえお", "斉斎齊齋", "\u{20B9F}\u{20D45}\u{20E6D}"].each do |str|
    puts "string: #{str}"
    puts "  unicode: #{str.unpack('U*')}"
    puts "  glyph  : #{font.convert_to_gid(str)}"
    puts "  width  : #{font.convert_to_gid(str).map{|gid| font.get_width(gid)}}"
  end
end
