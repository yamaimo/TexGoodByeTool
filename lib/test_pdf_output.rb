# テスト出力

require_relative 'sfnt_font'
require_relative 'sfnt_font_collection'
require_relative 'pdf_font'
require_relative 'length_extension'
require_relative 'pdf_document'
require_relative 'pdf_page'
require_relative 'pdf_graphic'
require_relative 'pdf_image'
require_relative 'pdf_destination'
require_relative 'pdf_outline_item'
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

snowman_png = PdfImage::Png.load('christmas_snowman.png')

using LengthExtension

# A5
page_width = 148.mm
page_height = 210.mm
document = PdfDocument.new(page_width, page_height)

document.add_font(pdf_font)
document.add_image(snowman_png)

def put_tex(text, fontsize)
  # base/plain.tex:\def\TeX{T\kern-.1667em\lower.5ex\hbox{E}\kern-.125emX}
  text.putc char: 'T'
  text.put_space -0.1667
  text.set_text_rise(-fontsize * 0.5 * 0.5)
  text.putc char: 'E'
  text.set_text_rise 0
  text.put_space -0.125
  text.putc char: 'X'
end

page = PdfPage.add_to(document)
page.add_content do |content|
  content.stack_graphic_state do
    content.move_origin 22.mm, 188.mm
    content.add_text do |text|
      text.set_font pdf_font, 14
      text.set_leading 16
      ["ABCDE", "あいうえお", "斉斎齊齋", "\u{20B9F}\u{20D45}\u{20E6D}"].each do |str|
        text.puts str
      end
      text.puts
      put_tex(text, 14)
      text.puts "グッバイしたい！"
    end
  end

  content.stack_graphic_state do
    content.move_origin 20.mm, 110.mm

    path = PdfGraphic::Path.new do
      from [0.cm, 0.cm]
      to [1.cm, 1.cm]
      to [2.cm, 0.cm], ctrl1: [1.552.cm, 1.cm], ctrl2: [2.cm, 0.448.cm]
    end

    graphic = PdfGraphic.new
    graphic.draw_on(content) do |pen|
      pen.stroke path
    end

    graphic.draw_on(content) do |pen|
      copied = path.clone
      copied.scale ratio: 0.8, anchor: [1.cm, 0.cm]
      pen.stroke copied
    end

    graphic.line_width = 5.pt
    graphic.line_cap = PdfGraphic::LineCapStyle::ROUND
    graphic.line_join = PdfGraphic::LineJoinStyle::ROUND
    graphic.draw_on(content) do |pen|
      copied = path.clone
      5.times do
        copied.move dx: 0.5.cm, dy: -1.5.cm
        pen.stroke copied
      end
    end

    graphic.line_cap = PdfGraphic::DEFAULT_LINE_CAP
    graphic.line_join = PdfGraphic::DEFAULT_LINE_JOIN
    graphic.dash_pattern = [4, 2]
    graphic.dash_phase = 2
    graphic.draw_on(content) do |pen|
      copied = path.clone
      5.times do
        copied.rotate rad: - Math::PI / 6, anchor: [3.cm, 0.cm]
        pen.stroke copied
      end
    end

    graphic.dash_pattern = PdfGraphic::DEFAULT_DASH_PATTERN
    graphic.dash_phase = PdfGraphic::DEFAULT_DASH_PHASE
    graphic.stroke_color = PdfColor::Rgb.new red: 1.0
    graphic.fill_color = PdfColor::Rgb.new green: 1.0
    graphic.draw_on(content) do |pen|
      copied = path.clone
      copied.h_flip x: 6.cm
      pen.stroke_fill copied
    end

    graphic.use_even_odd_rule = true
    graphic.draw_on(content) do |pen|
      copied = path.clone
      copied.h_flip x: 6.cm
      copied.v_flip y: 3.cm
      pen.stroke_fill copied
    end
  end

  content.stack_graphic_state do
    content.move_origin 108.mm, 40.mm

    scale_ratio = 50
    center = [0.5, 0.5]

    snowman_body = PdfGraphic::Path.new do
      from [0.5, 0.72]
      to [0.76, 0.55], ctrl1: [0.64, 0.72], ctrl2: [0.76, 0.65]
      to [0.67, 0.44], ctrl1: [0.76, 0.51], ctrl2: [0.72, 0.47]
      to [0.84, 0.25], ctrl1: [0.79, 0.41], ctrl2: [0.84, 0.32]
      to [0.68, 0.08], ctrl1: [0.84, 0.13], ctrl2: [0.75, 0.08]
      to [0.32, 0.08]
      to [0.16, 0.25], ctrl1: [0.25, 0.08], ctrl2: [0.16, 0.13]
      to [0.33, 0.44], ctrl1: [0.16, 0.32], ctrl2: [0.21, 0.41]
      to [0.24, 0.55], ctrl1: [0.28, 0.47], ctrl2: [0.24, 0.51]
      to [0.5,  0.72], ctrl1: [0.24, 0.65], ctrl2: [0.36, 0.72]
    end
    snowman_body.scale ratio: scale_ratio, anchor: center

    snowman_eyes = [
      PdfGraphic::Oval.new([0.38, 0.59], [0.42, 0.53]),
      PdfGraphic::Oval.new([0.58, 0.59], [0.62, 0.53]),
    ]
    snowman_eyes.each do |eye|
      eye.scale ratio: scale_ratio, anchor: center
    end

    snowman_mouth = PdfGraphic::Path.new do
      from [0.40, 0.48]
      to [0.60, 0.48], ctrl1: [0.45, 0.45], ctrl2: [0.55, 0.45]
    end
    snowman_mouth.scale ratio: scale_ratio, anchor: center

    snowman_hat = PdfGraphic::Path.new do
      from [0.58, 0.90]
      to [0.77, 0.81]
      to [0.74, 0.61]
      to [0.46, 0.72], ctrl1: [0.66, 0.60], ctrl2: [0.50, 0.66]
      to [0.58, 0.90]
    end
    snowman_hat.scale ratio: scale_ratio, anchor: center

    snowman_muffler = PdfGraphic::Path.new do
      from [0.27,0.48]
      to [0.73, 0.48], ctrl1: [0.42, 0.38], ctrl2: [0.58, 0.38]
      to [0.77, 0.41], ctrl1: [0.75, 0.46], ctrl2: [0.76, 0.44]
      to [0.73, 0.36], ctrl1: [0.77, 0.39], ctrl2: [0.75, 0.37]
      to [0.76, 0.26], ctrl1: [0.74, 0.33], ctrl2: [0.74, 0.31]
      to [0.66, 0.23], ctrl1: [0.75, 0.25], ctrl2: [0.72, 0.24]
      to [0.63, 0.34], ctrl1: [0.66, 0.27], ctrl2: [0.65, 0.30]
      to [0.24, 0.41], ctrl1: [0.42, 0.30], ctrl2: [0.32, 0.35]
      to [0.27, 0.48], ctrl1: [0.25, 0.45], ctrl2: [0.26, 0.47]
    end
    snowman_muffler.scale ratio: scale_ratio, anchor: center

    graphic = PdfGraphic.new
    graphic.line_cap = PdfGraphic::LineCapStyle::ROUND
    graphic.line_join = PdfGraphic::LineJoinStyle::ROUND
    graphic.draw_on(content) do |pen|
      pen.stroke snowman_body
      pen.stroke snowman_mouth
    end

    graphic.fill_color = PdfColor::Rgb.new
    graphic.draw_on(content) do |pen|
      snowman_eyes.each do |eye|
        pen.stroke_fill eye
      end
    end

    graphic.fill_color = PdfColor::Rgb.new red: 1.0
    graphic.draw_on(content) do |pen|
      pen.stroke_fill snowman_hat
      pen.stroke_fill snowman_muffler
    end
  end

  graphic = PdfGraphic.new
  graphic.draw_on(content) do |pen|
    basic_rect = PdfGraphic::Rectangle.new([7.cm, 8.cm], [10.cm, 10.cm])
    pen.stroke basic_rect

    round_rect = PdfGraphic::Rectangle.new([11.cm, 8.cm], [14.cm, 10.cm], round: 3.mm)
    pen.stroke round_rect

    circle = PdfGraphic::Oval.new([7.cm, 5.cm], [9.cm, 7.cm])
    pen.stroke circle

    oval = PdfGraphic::Oval.new([11.cm, 5.cm], [14.cm, 7.cm])
    pen.stroke oval
  end

  content.stack_graphic_state do
    content.move_origin 70.mm, 190.mm
    content.add_text do |text|
      text.set_font pdf_font, 14
      text.set_leading 16
      text.puts "雪だるまの後ろに文字を出力！"
      text.puts "マスクはちゃんと指定できてる？"
    end
  end

  image = PdfImage.new
  image.dpi = 350
  image.draw_on(content) do |pen|
    pen.paint snowman_png, x: 80.mm, y: 210.mm
  end

  content.add_text do |text|
    text.set_font pdf_font, 10
    text.return_cursor dy: (- sfnt_font.descender * 10 / 1000.0) # descenderの分だけ上へ移動
    text.puts "原点はここ"
  end
end

next_page = PdfPage.add_to(document)

document.add_destination("page1", PdfDestination.new(page, 0.mm, 210.mm))
document.add_destination("text", PdfDestination.new(page, 22.mm, 188.mm + 14.pt))
document.add_destination("snowman", PdfDestination.new(page, 108.mm-25.pt, 40.mm+25.pt))
document.add_destination("snowman_png", PdfDestination.new(page, 80.mm, 210.mm))
document.add_destination("page2", PdfDestination.new(next_page, 0.mm, 210.mm))

page1_outline = PdfOutlineItem.add_to(document, "Page 1", "page1")
PdfOutlineItem.add_to(page1_outline, "text", "text")
PdfOutlineItem.add_to(page1_outline, "snowman", "snowman")
PdfOutlineItem.add_to(page1_outline, "snowman.png", "snowman_png")
PdfOutlineItem.add_to(document, "Page 2", "page2")

writer = PdfWriter.new("output_test.pdf")
writer.write(document)
