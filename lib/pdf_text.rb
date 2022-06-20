# PDFテキスト

require_relative 'hex_extension'
require_relative 'pdf_serialize_extension'

class PdfText

  DEFAULT_LEADING = 0
  DEFAULT_TEXT_RISE = 0

  class Pen

    using HexExtension
    using PdfSerializeExtension

    def initialize(content, font)
      @content = content
      @font = font
    end

    def set_font(pdf_font, size)
      # NOTE: 今はここでpdf_fontに必要とされる機能がsfnt_fontと等しいので、
      # sfnt_fontも指定可能（本来はpdf_fontのみが指定されるべき）
      @content.add_operation "#{pdf_font.id.to_sym.serialize} #{size} Tf"
      @font = pdf_font
    end

    def set_leading(size)
      @content.add_operation "#{size} TL"
    end

    def set_text_rise(size)
      @content.add_operation "#{size} Ts"
    end

    def puts(str="")
      if str.nil? || str.empty?
        @content.add_operation "T*"
      else
        encoded = @font.convert_to_gid(str).map(&:to_hex_str).join
        @content.add_operation "<#{encoded}> Tj T*"
      end
    end

    def putc(char: nil, gid: 0)
      if char
        gid = @font.convert_to_gid(char).first
      end
      encoded = gid.to_hex_str
      @content.add_operation "<#{encoded}> Tj"
    end

    def put_space(n_chars)
      # 正だと間が狭まり、負だと間が広がる
      width = - n_chars * 1000
      @content.add_operation "[#{width}] TJ"
    end

    # カーソルを行頭に戻す
    # dx, dyが指定されていた場合、指定された分だけ行頭の位置を変更する
    def return_cursor(dx: 0, dy: 0)
      @content.add_operation "#{dx} #{dy} Td"
    end

  end

  def initialize(pdf_font, font_size)
    @font = pdf_font
    @size = font_size
    @leading = DEFAULT_LEADING
    @text_rise = DEFAULT_TEXT_RISE
  end

  attr_accessor :font, :size, :leading, :text_rise

  def write_in(content, &block)  # write_inがよさそう
    content.stack_graphic_state do
      pen = Pen.new(content, @font)

      content.add_operation "BT"

      pen.set_font(@font, @size) if @font # FIXME: 本来@fontはnilでないべき
      pen.set_leading(@leading) if @leading != DEFAULT_LEADING
      pen.set_text_rise(@text_rise) if @text_rise != DEFAULT_TEXT_RISE

      block.call(pen)

      content.add_operation "ET"
    end
  end

end

if __FILE__ == $0
  require_relative 'pdf_page'
  require_relative 'sfnt_font'
  require_relative 'pdf_font'
  require_relative 'pdf_object_binder'

  def put_tex(pen, fontsize)
    # base/plain.tex:\def\TeX{T\kern-.1667em\lower.5ex\hbox{E}\kern-.125emX}
    pen.putc char: 'T'
    pen.put_space -0.1667
    pen.set_text_rise(-fontsize * 0.5 * 0.5)
    pen.putc char: 'E'
    pen.set_text_rise 0
    pen.put_space -0.125
    pen.putc char: 'X'
  end

  content = PdfPage::Content.new

  sfnt_font = SfntFont.load('ipaexm.ttf')
  pdf_font = PdfFont.new(sfnt_font)
  font_size = 14
  line_gap = font_size / 2

  text = PdfText.new(pdf_font, font_size)
  text.leading = font_size + line_gap
  text.write_in(content) do |pen|
    ["ABCDE", "あいうえお", "斉斎齊齋", "\u{20B9F}\u{20D45}\u{20E6D}"].each do |str|
      pen.puts str
    end
    pen.puts
    put_tex(pen, 14)
    pen.puts "グッバイしたい！"
  end

  binder = PdfObjectBinder.new
  content.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
