# 組版文字

class TypesetChar

  def initialize(char, gid, width, ascender, descender)
    @char = char
    @gid = gid
    @width = width
    @ascender = ascender
    @descender = descender
  end

  attr_reader :gid, :width, :ascender, :descender

  def height
    @ascender - @descender
  end

  def write_with(pen)
    pen.putc(gid: @gid)
  end

  def to_s
    @char
  end

end

if __FILE__ == $0
  require_relative 'sfnt_font'
  require_relative 'length_extension'
  require_relative 'pdf_document'
  require_relative 'pdf_font'
  require_relative 'pdf_page'
  require_relative 'pdf_text'
  require_relative 'pdf_object_binder'

  using LengthExtension

  sfnt_font = SfntFont.load('ipaexm.ttf')
  font_size = 14

  char = 'あ'
  gid = sfnt_font.convert_to_gid(char).first
  width = sfnt_font.widths[gid] * font_size / 1000.0
  ascender = sfnt_font.ascender * font_size / 1000.0
  descender = sfnt_font.descender * font_size / 1000.0

  typeset_char = TypesetChar.new('あ', gid, width, ascender, descender)
  puts "char     : #{typeset_char}"
  puts "gid      : #{typeset_char.gid}"
  puts "width    : #{typeset_char.width}"
  puts "height   : #{typeset_char.height}"
  puts "ascender : #{typeset_char.ascender}"
  puts "descender: #{typeset_char.descender}"

  # A5
  page_width = 148.mm
  page_height = 210.mm
  document = PdfDocument.new(page_width, page_height)

  pdf_font = PdfFont.new(sfnt_font)
  document.add_font(pdf_font)

  page = PdfPage.add_to(document)
  page.add_content do |content|
    content.move_origin 22.mm, 188.mm
    text = PdfText.new(pdf_font, font_size)
    text.write_in(content) do |pen|
      typeset_char.write_with(pen)
    end
  end

  binder = PdfObjectBinder.new
  # pageの内容だけ見る
  page.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
