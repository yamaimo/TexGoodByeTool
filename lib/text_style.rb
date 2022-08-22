# テキストスタイル

require_relative 'pdf_text'

class TextStyle

  # leadingはボックス側の設定 -> ここでもいいかも
  # text_rise, rendering_modeなどは後回し
  def initialize(font: nil, size: nil, verbatim: nil)
    @font = font
    @size = size
    @verbatim = verbatim
  end

  attr_reader :font, :size, :verbatim
  alias_method :verbatim?, :verbatim

  def create_inherit_style(parent_style)
    font = @font || parent_style.font
    size = @size || parent_style.size
    verbatim = @verbatim.nil? ? parent_style.verbatim : @verbatim
    TextStyle.new(font: font, size: size, verbatim: verbatim)
  end

  def to_pdf_text_setting
    PdfText::Setting.new(self.font, self.size)
  end

end

if __FILE__ == $0
  require_relative 'sfnt_font'
  require_relative 'pdf_font'
  require_relative 'length_extension'
  require_relative 'pdf_document'
  require_relative 'pdf_page'
  require_relative 'pdf_object_binder'

  sfnt_font = SfntFont.load('ipaexm.ttf')
  pdf_font = PdfFont.new(sfnt_font)

  sfnt_font_2 = SfntFont.load('ipaexm.ttf') # IDは別になる
  pdf_font_2 = PdfFont.new(sfnt_font_2)

  parent_style = TextStyle.new(font: pdf_font, size: 16, verbatim: false)
  puts "parent:"
  puts "  font: #{parent_style.font.id}"
  puts "  size: #{parent_style.size}"
  puts "  verb: #{parent_style.verbatim?}"

  child1_style_base = TextStyle.new(size: 14)
  child1_style = child1_style_base.create_inherit_style(parent_style)
  puts "child1:"
  puts "  font: #{child1_style.font.id}"
  puts "  size: #{child1_style.size}"
  puts "  verb: #{child1_style.verbatim?}"

  child2_style_base = TextStyle.new(font: pdf_font_2, verbatim: true)
  child2_style = child2_style_base.create_inherit_style(parent_style)
  puts "child2:"
  puts "  font: #{child2_style.font.id}"
  puts "  size: #{child2_style.size}"
  puts "  verb: #{child2_style.verbatim?}"

  child3_style_base = TextStyle.new(size: 10)
  child3_style = child3_style_base.create_inherit_style(child2_style)
  puts "child3:"
  puts "  font: #{child3_style.font.id}"
  puts "  size: #{child3_style.size}"
  puts "  verb: #{child3_style.verbatim?}"

  using LengthExtension

  # A5
  page_width = 148.mm
  page_height = 210.mm
  document = PdfDocument.new(page_width, page_height)
  page = PdfPage.add_to(document)
  page.add_content do |content|
    parent_style.to_pdf_text_setting.get_pen_for(content) do |pen|
      # do nothing
    end
  end

  binder = PdfObjectBinder.new
  # pageの内容だけ見る
  page.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
