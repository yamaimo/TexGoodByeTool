# テキストスタイル

require_relative 'pdf_text'

class TextStyle

  # FIXME: 他、text_rise, rendering_modeなども必要そう

  def initialize
    @font = nil # 継承
    @size = nil # 継承
    @verbatim = nil # 継承
  end

  attr_reader :font, :size, :verbatim
  alias_method :verbatim?, :verbatim

  def font=(font)
    @font = font if font
  end

  def size=(size)
    @size = size if size
  end

  def verbatim=(bool)
    @verbatim = bool unless bool.nil?
  end

  def create_inherit_style(parent_style)
    style = self.dup
    style.font = parent_style.font if @font.nil?
    style.size = parent_style.size if @size.nil?
    style.verbatim = parent_style.verbatim if @verbatim.nil?
    style
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

  parent_style = TextStyle.new
  parent_style.font = pdf_font
  parent_style.size = 16
  parent_style.verbatim = false
  parent_style.freeze
  puts "parent:"
  puts "  font: #{parent_style.font.id}"
  puts "  size: #{parent_style.size}"
  puts "  verb: #{parent_style.verbatim?}"

  child1_style_base = TextStyle.new
  child1_style_base.size = 14
  child1_style_base.freeze
  child1_style = child1_style_base.create_inherit_style(parent_style).freeze
  puts "child1:"
  puts "  font: #{child1_style.font.id}"
  puts "  size: #{child1_style.size}"
  puts "  verb: #{child1_style.verbatim?}"

  child2_style_base = TextStyle.new
  child2_style_base.font = pdf_font_2
  child2_style_base.verbatim = true
  child2_style_base.freeze
  child2_style = child2_style_base.create_inherit_style(parent_style).freeze
  puts "child2:"
  puts "  font: #{child2_style.font.id}"
  puts "  size: #{child2_style.size}"
  puts "  verb: #{child2_style.verbatim?}"

  child3_style_base = TextStyle.new
  child3_style_base.size = 10
  child3_style_base.freeze
  child3_style = child3_style_base.create_inherit_style(child2_style).freeze
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
