# テスト出力

require_relative 'sfnt_font'
require_relative 'sfnt_font_collection'
require_relative 'pdf_font'
require_relative 'length_extension'
require_relative 'pdf_document'
require_relative 'pdf_page'
require_relative 'pdf_writer'

if ARGV.empty?
  puts "[Font file list] ----------"
  puts SfntFont.list
  puts "[Font collection file list] ----------"
  SfntFontCollection.list.each do |filename|
    puts filename
    SfntFontCollection.list_collection(filename).each_with_index do |name, i|
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
pdf_font = PdfFont.new(sfnt_font)

using LengthExtension

# A5
page_width = 148.mm
page_height = 210.mm
document = PdfDocument.new(page_width, page_height)

document.add_font(pdf_font)

page = PdfPage.add_to(document)
page.add_content do |content|
  content.stack_origin do
    content.move_origin 22.mm, 188.mm
    content.add_text do |text|
      text.set_font pdf_font.id, 14
      text.set_leading 16
      ["ABCDE", "あいうえお", "斉斎齊齋", "\u{20B9F}\u{20D45}\u{20E6D}"].each do |str|
        text.puts str
      end
      text.puts
      text.puts "TeXグッバイしたい！"
    end
  end

  content.add_text do |text|
    text.set_font pdf_font.id, 10
    text.return_cursor dy: (- sfnt_font.descender * 10 / 1000.0) # descenderの分だけ上へ移動
    text.puts "原点はここ"
  end
end

writer = PdfWriter.new("test.pdf")
writer.write(document)
