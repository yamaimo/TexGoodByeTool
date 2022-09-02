# 組版オブジェクト：文字

class TypesetChar
  # child: (none)
  # parent: TypesetText
  #   require: -
  #   required: .create, #width, #stretch?, #strut?, #write_with, #to_s

  def self.create(char, font, size)
    gid = font.convert_to_gid(char).first
    width = font.get_width(gid) * size / 1000.0
    self.new(char, gid, width)
  end

  def initialize(char, gid, width)
    @char = char
    @gid = gid
    @width = width
  end

  attr_reader :char, :gid, :width
  alias_method :to_s, :char

  def stretch?
    false
  end

  def strut?
    false
  end

  def write_with(pen)
    pen.putc(gid: @gid)
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
  pdf_font = PdfFont.new(sfnt_font)
  font_size = 14

  typeset_char = TypesetChar.create('あ', pdf_font, font_size)
  puts "char     : #{typeset_char}"
  puts "gid      : #{typeset_char.gid}"
  puts "width    : #{typeset_char.width}"

  # A5
  page_width = 148.mm
  page_height = 210.mm
  document = PdfDocument.new(page_width, page_height)

  document.add_font(pdf_font)
  text_setting = PdfText::Setting.new(pdf_font, font_size)

  page = PdfPage.add_to(document)
  page.add_content do |content|
    content.move_origin 22.mm, 188.mm
    text_setting.get_pen_for(content) do |pen|
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
