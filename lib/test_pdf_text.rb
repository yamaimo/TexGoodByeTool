# テキストのテスト出力

require_relative 'sfnt_font'
require_relative 'sfnt_font_collection'
require_relative 'length_extension'
require_relative 'pdf_document'
require_relative 'pdf_page'
require_relative 'pdf_font'
require_relative 'pdf_text'
require_relative 'pdf_writer'

if ARGV.empty?
  puts "[Font file list] ----------"
  puts SfntFont.list
  puts "[Font collection file list] ----------"
  SfntFontCollection.list.each do |filename|
    puts filename
    collections = SfntFontCollection.list_collection(filename)
    collections.each_with_index do |name, i|
      puts "[#{i}] #{name}"
    end
  end
  puts "---------------------------"
  raise "No font file is specified."
end

filename = ARGV[0]
sfnt_font = if ARGV.size == 1
              SfntFont.load(filename)
            else
              index = ARGV[1].to_i
              SfntFontCollection.load(filename, index)
            end

using LengthExtension

# A5
page_width = 148.mm
page_height = 210.mm
document = PdfDocument.new(page_width, page_height)

document.title = "テキストのテスト出力"
document.author = "やまいも"

pdf_font = PdfFont.new(sfnt_font)
document.add_font(pdf_font)

page = PdfPage.add_to(document)
page.add_content do |content|
  content.stack_graphic_state do
    content.move_origin 22.mm, 188.mm

    text = PdfText.new(pdf_font, 14)
    text.leading = 16
    text.write_in(content) do |pen|
      # 文字の出力
      strs = [
        "ABCDE", "あいうえお", "斉斎齊齋",
        "\u{20B9F}\u{20D45}\u{20E6D}",
      ]
      strs.each do |str|
        pen.puts str
      end

      pen.puts

      # TeXの出力
      def put_tex(pen, fontsize)
        # base/plain.tex:
        # \def\TeX{T\kern-.1667em\lower.5ex\hbox{E}\kern-.125emX}
        pen.putc char: 'T'
        pen.put_space -0.1667
        pen.set_text_rise(-fontsize * 0.5 * 0.5)
        pen.putc char: 'E'
        pen.set_text_rise 0
        pen.put_space -0.125
        pen.putc char: 'X'
      end

      put_tex(pen, 14)
      pen.puts "グッバイしたい！"
    end
  end
end

writer = PdfWriter.new("text_test.pdf")
writer.write(document)
