# SFNT形式フォント（TrueType, OpenType）

require 'pathname'
require 'forwardable'

require_relative 'extname_extension'
require_relative 'table_directory'
require_relative 'head_table'
require_relative 'name_table'
require_relative 'post_table'
require_relative 'os2_table'
require_relative 'cmap_table'
require_relative 'hhea_table'
require_relative 'hmtx_table'

class SfntFont

  extend Forwardable

  using ExtnameExtension

  def self.extnames
    ['.ttf', '.otf']
  end

  def self.search_path
    @search_path ||= [
      Pathname.pwd,
      Pathname.new(Dir.home)/'Library'/'Fonts',
      Pathname.new('/System/Library/Fonts'),
      Pathname.new('/Library/Fonts'),
    ].delete_if(&:nil?)
  end

  def self.find_path(filename)
    found = nil

    filename = Pathname.new(filename) unless filename.is_a?(Pathname)

    if filename.absolute?
      if filename.exist?
        found = filename
      end
    else
      self.search_path.each do |path|
        if (path/filename).exist?
          found = path/filename
          break
        end
      end
    end

    if not found
      raise "Font file '#{filename}' is not found."
    end

    found
  end

  def self.list
    self.search_path.map do |path|
      path.children(false).keep_if do |filename|
        filename.is_extname?(self.extnames)
      end
    end.flatten
  end

  def self.load(filename)
    path = self.find_path(filename)
    path.open do |file|
      table_directory = TableDirectory.from_file(file)
      head, name, post, os2, cmap, hhea, hmtx = self.load_tables(file, table_directory)
      self.new(path, table_directory.type, head, name, post, os2, cmap, hhea, hmtx)
    end
  end

  def self.load_tables(file, table_directory)
    head = HeadTable.from_file(file, table_directory.records['head'])
    name = NameTable.from_file(file, table_directory.records['name'])
    post = PostTable.from_file(file, table_directory.records['post'])
    os2 = Os2Table.from_file(file, table_directory.records['OS/2'], head.units)
    cmap = CmapTable.from_file(file, table_directory.records['cmap'])
    hhea = HheaTable.from_file(file, table_directory.records['hhea'], head.units)
    hmtx = HmtxTable.from_file(file, table_directory.records['hmtx'], hhea.hmetrics_count, head.units)
    [head, name, post, os2, cmap, hhea, hmtx]
  end

  def initialize(path, type, head, name, post, os2, cmap, hhea, hmtx)
    @path = path
    @type = type
    @head = head
    @name = name
    @post = post
    @os2 = os2
    @cmap = cmap
    @hhea = hhea
    @hmtx = hmtx
    @name_cache = nil
  end

  attr_reader :path, :type

  def_delegators :@head, :bound_box

  def_delegators :@post, :italic_angle, :italic?, :fixed_pitch?

  def_delegators :@os2, :weight, :bold?, :serif?, :script?

  def_delegators :@cmap, :gid_cache, :convert_to_gid, :find_gid

  def_delegators :@hmtx, :widths, :mode_width, :get_width

  def id
    "Font#{self.object_id}"
  end

  def name
    if @name_cache.nil?
      @name_cache = @name.find(NameTable::NameID::POSTSCRIPT_NAME)
      if @name_cache.nil?
        family_name_ids = [
          NameTable::NameID::FONT_FAMILY_NAME,
          NameTable::NameID::TYPOGRAPHIC_FAMILY_NAME,
        ]
        subfamily_name_ids = [
          NameTable::NameID::FONT_SUBFAMILY_NAME,
          NameTable::NameID::TYPOGRAPHIC_SUBFAMILY_NAME,
        ]

        family = nil
        family_name_ids.each do |name_id|
          family = @name.find(name_id)
          break if family
        end
        family = @path.basename(".*").to_s if family.nil?

        subfamily = nil
        subfamily_name_ids.each do |name_id|
          subfamily = @name.find(name_id)
          break if subfamily
        end

        @name_cache = \
          subfamily ? [family, subfamily].join(',') : family
      end
    end
    @name_cache
  end

  def ascender
    # hheaとos2にある；大きい方を使うことにする
    [@hhea.ascender, @os2.ascender].max
  end

  def descender
    # hheaとos2にある；小さい方を使うことにする
    [@hhea.descender, @os2.descender].min
  end

  def line_gap
    # hheaとos2にある；大きい方を使うことにする
    [@hhea.line_gap, @os2.line_gap].max
  end

  def to_stream
    stream = File.open(@path, 'rb') do |file|
      # ファイル長取得
      file.seek(0, IO::SEEK_END)
      length = file.pos
      file.seek(0, IO::SEEK_SET)

      # バイナリ読み込み
      file.read(length)
    end
    stream
  end

end

if __FILE__ == $0
  if ARGV.empty?
    puts "[Font file list] ----------"
    puts SfntFont.list
    puts "---------------------------"
    raise "No font file is specified."
  end

  filename = ARGV[0]
  font = SfntFont.load(filename)
  puts "path: #{font.path}"
  puts "type: #{font.type}"
  puts "id  : #{font.id}"
  puts "name: #{font.name}"
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
