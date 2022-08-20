# テキスト設定

require_relative 'pdf_text'

class TextSetting

  # leadingはボックス側の設定 -> ここでもいいかも
  # text_rise, rendering_modeなどは後回し
  def initialize(parent: nil, font: nil, size: nil, verbatim: nil)
    @parent = parent
    @font = font
    @size = size
    @verbatim = verbatim
  end

  def font
    @font ||= @parent.font
  end

  def size
    @size ||= @parent.size
  end

  def verbatim?
    if @verbatim.nil?
      @verbatim = @parent.verbatim?
    end
    @verbatim
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

  parent_setting = TextSetting.new(font: pdf_font, size: 16, verbatim: false)
  puts "parent:"
  puts "  font: #{parent_setting.font.id}"
  puts "  size: #{parent_setting.size}"
  puts "  verb: #{parent_setting.verbatim?}"

  child1_setting = TextSetting.new(parent: parent_setting, size: 14)
  puts "child1:"
  puts "  font: #{child1_setting.font.id}"
  puts "  size: #{child1_setting.size}"
  puts "  verb: #{child1_setting.verbatim?}"

  child2_setting = TextSetting.new(parent: parent_setting, font: pdf_font_2, verbatim: true)
  puts "child2:"
  puts "  font: #{child2_setting.font.id}"
  puts "  size: #{child2_setting.size}"
  puts "  verb: #{child2_setting.verbatim?}"

  child3_setting = TextSetting.new(parent: child2_setting, size: 10)
  puts "child3:"
  puts "  font: #{child3_setting.font.id}"
  puts "  size: #{child3_setting.size}"
  puts "  verb: #{child3_setting.verbatim?}"

  using LengthExtension

  # A5
  page_width = 148.mm
  page_height = 210.mm
  document = PdfDocument.new(page_width, page_height)
  page = PdfPage.add_to(document)
  page.add_content do |content|
    parent_setting.to_pdf_text_setting.get_pen_for(content) do |pen|
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
