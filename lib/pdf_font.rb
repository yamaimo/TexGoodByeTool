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

    def attach_to(binder)
      @font_descriptor.attach_to(binder)

      subtype = case @sfnt_font.type
                when SfntFontType::OPEN_TYPE
                  :CIDFontType0
                when SfntFontType::TRUE_TYPE
                  :CIDFontType2
                else
                  raise "Unknown type."
                end

      cid_font_dict = {
        Type: :Font,
        Subtype: subtype,
        BaseFont: @sfnt_font.name.to_sym,
        CIDSystemInfo: {
          Registry: "Adobe",
          Ordering: "Identity",
          Supplement: 0,
        },
        FontDescriptor: binder.get_ref(@font_descriptor),
        DW: @sfnt_font.mode_width,
        W: get_w_records,
      }
      binder.attach(self, cid_font_dict)
    end

    private

    def get_w_records
      w_records = []

      mode_width = @sfnt_font.mode_width

      start_gid = nil
      widths = []
      @sfnt_font.widths.each_with_index do |width, gid|
        if width != mode_width
          start_gid = gid if start_gid.nil?
          widths.push width
        else
          if start_gid
            w_records.push start_gid
            w_records.push widths
            start_gid = nil
            widths = []
          end
        end
      end
      if start_gid
        w_records.push start_gid
        w_records.push widths
      end

      w_records
    end

  end

  class FontDescriptor

    def initialize(sfnt_font, font_file)
      @sfnt_font = sfnt_font
      @font_file = font_file
    end

    def attach_to(binder)
      @font_file.attach_to(binder)

      flags = 0x04  # symbolic, latin以外も含んでいい
      flags |= 0x01 if @sfnt_font.fixed_pitch?
      flags |= 0x02 if @sfnt_font.serif?
      flags |= 0x08 if @sfnt_font.script?
      flags |= 0x40 if @sfnt_font.italic?
      # AllCap, SmallCap, ForceBoldはとれない

      # CapHeightは可能ならOS/2テーブルからとった方がいいが
      # ascenderの値で代用
      cap_height = @sfnt_font.ascender

      # StemVは適切な値をとるのが難しいので
      # 太さを適当な大きさにしておく
      stem_v = @sfnt_font.weight / 5

      font_desc_dict = {
        Type: :FontDescriptor,
        FontName: @sfnt_font.name.to_sym,
        FontBBox: @sfnt_font.bound_box,
        ItalicAngle: @sfnt_font.italic_angle,
        Ascent: @sfnt_font.ascender,
        Descent: @sfnt_font.descender,
        Flags: flags,
        CapHeight: cap_height,
        StemV: stem_v,
      }

      case @sfnt_font.type
      when SfntFontType::OPEN_TYPE
        font_desc_dict[:FontFile3] = binder.get_ref(@font_file)
      when SfntFontType::TRUE_TYPE
        font_desc_dict[:FontFile2] = binder.get_ref(@font_file)
      else
        raise "Unknown type."
      end

      binder.attach(self, font_desc_dict)
    end

  end

  class FontFile

    def initialize(sfnt_font)
      @sfnt_font = sfnt_font
    end

    def attach_to(binder)
      stream = @sfnt_font.to_stream
      length = stream.bytesize

      compressed = Zlib::Deflate.deflate(stream)
      compressed_length = compressed.bytesize

      stream_dict = {
        Filter: :FlateDecode,
        Length: compressed_length,
      }

      case @sfnt_font.type
      when SfntFontType::OPEN_TYPE
        stream_dict[:Subtype] = :CIDFontType0C
      when SfntFontType::TRUE_TYPE
        stream_dict[:Length1] = length
      else
        raise "Unknown type."
      end

      binder.attach(self, stream_dict, compressed)
    end

  end

  class ToUnicode

    using HexExtension

    def initialize(sfnt_font)
      @sfnt_font = sfnt_font
    end

    def attach_to(binder)
      entry = @sfnt_font.gid_cache.filter do |cid, gid|
        gid != CmapTable::GID_NOT_FOUND
      end
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

      binder.attach(self, {Length: length}, to_unicode_cmap)
    end

  end

  def initialize(sfnt_font)
    @sfnt_font = sfnt_font

    font_file = FontFile.new(sfnt_font)
    font_descriptor = FontDescriptor.new(sfnt_font, font_file)
    @cid_font = CidFont.new(sfnt_font, font_descriptor)

    @to_unicode = ToUnicode.new(sfnt_font)
  end

  def attach_to(binder)
    @cid_font.attach_to(binder)
    @to_unicode.attach_to(binder)

    name = @sfnt_font.name
    encoding = "Identity-H"
    if @sfnt_font.type == SfntFontType::OPEN_TYPE
      name = "#{name}-#{encoding}"
    end

    font_dict = {
      Type: :Font,
      Subtype: :Type0,
      BaseFont: name.to_sym,
      Encoding: encoding.to_sym,
      DescendantFonts: [binder.get_ref(@cid_font)],
      ToUnicode: binder.get_ref(@to_unicode),
    }
    binder.attach(self, font_dict)
  end

  def_delegators :@sfnt_font, :id, :convert_to_gid, :find_gid
  def_delegators :@sfnt_font, :get_width, :ascender, :descender

end

if __FILE__ == $0
  require_relative 'sfnt_font'
  require_relative 'pdf_object_binder'

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

  binder = PdfObjectBinder.new
  pdf_font.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
