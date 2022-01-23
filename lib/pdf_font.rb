# PDFフォント

require 'forwardable'
require 'zlib'

require_relative 'sfnt_font_type'
require_relative 'cmap_table'
require_relative 'hex_extension'

class PdfFont

  extend Forwardable

  class CidFont

    def initialize(sfnt_font, font_descriptor)
      @sfnt_font = sfnt_font
      @font_descriptor = font_descriptor
    end

    def attach_content_to(pool)
      @font_descriptor.attach_content_to(pool)

      subtype = case @sfnt_font.type
                when SfntFontType::OPEN_TYPE
                  "CIDFontType0"
                when SfntFontType::TRUE_TYPE
                  "CIDFontType2"
                else
                  raise "Unknown type."
                end

      pool.attach_content(self, <<~END_OF_CID_FONT)
        <<
          /Type /Font
          /Subtype /#{subtype}
          /BaseFont /#{@sfnt_font.name}
          /CIDSystemInfo <<
            /Registry (Adobe)
            /Ordering (Identity)
            /Supplement 0
          >>
          /FontDescriptor #{pool.get_ref(@font_descriptor)}
          /DW #{@sfnt_font.mode_width}
          /W [
            #{get_w_records.join("\n    ")}
          ]
        >>
      END_OF_CID_FONT
    end

    private

    def get_w_records
      w_records = []

      mode_width = @sfnt_font.mode_width
      record = nil
      @sfnt_font.widths.each_with_index do |width, gid|
        if width != mode_width
          if record.nil?
            record = [gid, width]
          else
            record.push width
          end
        else
          if record
            w_records.push "#{record[0]} [#{record[1..-1].join(' ')}]"
            record = nil
          end
        end
      end
      if record
        w_records.push "#{record[0]} [#{record[1..-1].join(' ')}]"
      end

      w_records
    end

  end

  class FontDescriptor

    def initialize(sfnt_font, font_file)
      @sfnt_font = sfnt_font
      @font_file = font_file
    end

    def attach_content_to(pool)
      @font_file.attach_content_to(pool)

      font_file_type = case @sfnt_font.type
                       when SfntFontType::OPEN_TYPE
                         "FontFile3"
                       when SfntFontType::TRUE_TYPE
                         "FontFile2"
                       else
                         raise "Unknown type."
                       end

      flags = 0x04  # symbolic, latin以外も含んでいい
      flags |= 0x01 if @sfnt_font.fixed_pitch?
      flags |= 0x02 if @sfnt_font.serif?
      flags |= 0x08 if @sfnt_font.script?
      flags |= 0x40 if @sfnt_font.italic?
      # AllCap, SmallCap, ForceBoldはとれない

      # CapHeightは可能ならOS/2テーブルからとった方がいいがascenderの値で代用
      cap_height = @sfnt_font.ascender

      # StemVは適切な値をとるのが難しいので太さを適当な大きさにしておく
      stem_v = @sfnt_font.weight / 5

      pool.attach_content(self, <<~END_OF_FONT_DESCRIPTOR)
        <<
          /Type /FontDescriptor
          /FontName /#{@sfnt_font.name}
          /FontBBox [#{@sfnt_font.bound_box.join(' ')}]
          /ItalicAngle #{@sfnt_font.italic_angle}
          /Ascent #{@sfnt_font.ascender}
          /Descent #{@sfnt_font.descender}
          /Flags #{flags}
          /CapHeight #{cap_height}
          /StemV #{stem_v}
          /#{font_file_type} #{pool.get_ref(@font_file)}
        >>
      END_OF_FONT_DESCRIPTOR
    end

  end

  class FontFile

    def initialize(sfnt_font)
      @sfnt_font = sfnt_font
    end

    def attach_content_to(pool)
      stream = @sfnt_font.to_stream
      length = stream.bytesize

      compressed = Zlib::Deflate.deflate(stream)
      compressed_length = compressed.bytesize

      additional_entry = case @sfnt_font.type
                         when SfntFontType::OPEN_TYPE
                           "/Subtype /CIDFontType0C"
                         when SfntFontType::TRUE_TYPE
                           "/Length1 #{length}"
                         else
                           raise "Unknown type."
                         end

      pool.attach_content(self, <<~END_OF_FONT_FILE)
        <<
          /Filter /FlateDecode
          /Length #{compressed_length}
          #{additional_entry}
        >>
        stream
        #{compressed}
        endstream
      END_OF_FONT_FILE
    end

  end

  class ToUnicode

    using HexExtension

    def initialize(sfnt_font)
      @sfnt_font = sfnt_font
    end

    def attach_content_to(pool)
      entry = @sfnt_font.gid_cache.filter{|cid, gid| gid != CmapTable::GID_NOT_FOUND}
      gid_to_cid_map = entry.map do |cid, gid|
        gid_hex_str = gid.to_hex_str
        cid_utf16be_hex_str = cid.to_utf16be_hex_str

        "<#{gid_hex_str}> <#{cid_utf16be_hex_str}>"
      end.join("\n")

      to_unicode_cmap = <<~END_OF_TO_UNICODE_CMAP.chomp
        /CIDInit /ProcSet findresource begin
        12 dict begin
        begincmap
        /CIDSystemInfo <<
          /Registry (Adobe)
          /Ordering (UCS)
          /Supplement 0
        >> def
        /CMapName /Adobe-Identity-UCS def
        /CMapType 2 def
        1 begincodespacerange
        <0000> <ffff>
        endcodespacerange
        #{entry.size} beginbfchar
        #{gid_to_cid_map}
        endbfchar
        endcmap
        CMapName currentdict /CMap defineresource pop
        end
        end
      END_OF_TO_UNICODE_CMAP
      length = to_unicode_cmap.bytesize + "\n".bytesize

      pool.attach_content(self, <<~END_OF_TO_UNICODE)
        <<
          /Length #{length}
        >>
        stream
        #{to_unicode_cmap}
        endstream
      END_OF_TO_UNICODE
    end


  end

  def initialize(sfnt_font)
    @sfnt_font = sfnt_font

    font_file = FontFile.new(sfnt_font)
    font_descriptor = FontDescriptor.new(sfnt_font, font_file)
    @cid_font = CidFont.new(sfnt_font, font_descriptor)

    @to_unicode = ToUnicode.new(sfnt_font)
  end

  def attach_content_to(pool)
    @cid_font.attach_content_to(pool)
    @to_unicode.attach_content_to(pool)

    name = @sfnt_font.name
    encoding = "Identity-H"
    if @sfnt_font.type == SfntFontType::OPEN_TYPE
      name = "#{name}-#{encoding}"
    end

    pool.attach_content(self, <<~END_OF_FONT)
      <<
        /Type /Font
        /Subtype /Type0
        /BaseFont /#{name}
        /Encoding /#{encoding}
        /DescendantFonts [#{pool.get_ref(@cid_font)}]
        /ToUnicode #{pool.get_ref(@to_unicode)}
      >>
    END_OF_FONT
  end

  def_delegators :@sfnt_font, :id, :convert_to_gid, :find_gid

end

if __FILE__ == $0
  require_relative 'sfnt_font'
  require_relative 'pdf_object_pool'

  if ARGV.empty?
    puts "[Font file list] ----------"
    puts SfntFont.list
    puts "---------------------------"
    raise "No font file is specified."
  end

  filename = ARGV[0]
  sfnt_font = SfntFont.load(filename)

  pdf_font = PdfFont.new(sfnt_font)

  ["ABCDE", "あいうえお", "斉斎齊齋", "\u{20B9F}\u{20D45}\u{20E6D}"].each do |str|
    puts "string: #{str}"
    puts "  unicode: #{str.unpack('U*')}"
    puts "  glyph  : #{pdf_font.convert_to_gid(str)}"
  end

  pool = PdfObjectPool.new
  pdf_font.attach_content_to(pool)

  pool.contents.each do |content|
    puts content
  end
end
