# PDFのテスト出力

require 'uri'

require_relative 'sfnt_font'
require_relative 'sfnt_font_collection'
require_relative 'length_extension'
require_relative 'pdf_document'
require_relative 'pdf_page'
require_relative 'pdf_graphic'
require_relative 'pdf_image'
require_relative 'pdf_font'
require_relative 'pdf_text'
require_relative 'pdf_destination'
require_relative 'pdf_internal_link'
require_relative 'pdf_external_link'
require_relative 'pdf_outline_item'
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

document.title = "PDFのテスト出力"
document.author = "やまいも"

snowman_png = PdfImage::Png.load('christmas_snowman.png')
document.add_image(snowman_png)

pdf_font = PdfFont.new(sfnt_font)
document.add_font(pdf_font)

# 雪だるまの描画
# （座標はscsnowmanを参考にした）
def draw_snowman(content, center, length, rad, color)
  content.stack_graphic_state do
    center_x, center_y = center
    origin_x = center_x - length * 0.5
    origin_y = center_y - length * 0.42
    content.move_origin origin_x, origin_y

    rotate_anchor = [length * 0.5, length * 0.42]

    # 体
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
    snowman_body.scale ratio: length
    snowman_body.rotate rad: rad, anchor: rotate_anchor

    # 目
    snowman_eyes = [
      PdfGraphic::Oval.new([0.38, 0.59], [0.42, 0.53]),
      PdfGraphic::Oval.new([0.58, 0.59], [0.62, 0.53]),
    ]
    snowman_eyes.each do |eye|
      eye.scale ratio: length
      eye.rotate rad: rad, anchor: rotate_anchor
    end

    # 口
    snowman_mouth = PdfGraphic::Path.new do
      from [0.40, 0.48]
      to [0.60, 0.48], ctrl1: [0.45, 0.45], ctrl2: [0.55, 0.45]
    end
    snowman_mouth.scale ratio: length
    snowman_mouth.rotate rad: rad, anchor: rotate_anchor

    # 帽子
    snowman_hat = PdfGraphic::Path.new do
      from [0.58, 0.90]
      to [0.77, 0.81]
      to [0.74, 0.61]
      to [0.46, 0.72], ctrl1: [0.66, 0.60], ctrl2: [0.50, 0.66]
      to [0.58, 0.90]
    end
    snowman_hat.scale ratio: length
    snowman_hat.rotate rad: rad, anchor: rotate_anchor

    # マフラー
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
    snowman_muffler.scale ratio: length
    snowman_muffler.rotate rad: rad, anchor: rotate_anchor

    # 描画
    graphic = PdfGraphic.new
    graphic.line_cap = PdfGraphic::LineCapStyle::ROUND
    graphic.line_join = PdfGraphic::LineJoinStyle::ROUND
    graphic.write_in(content) do |pen|
      pen.stroke snowman_body
      pen.stroke snowman_mouth
    end

    graphic.fill_color = PdfColor::Rgb.new
    graphic.write_in(content) do |pen|
      snowman_eyes.each do |eye|
        pen.stroke_fill eye
      end
    end

    graphic.fill_color = color
    graphic.write_in(content) do |pen|
      pen.stroke_fill snowman_hat
      pen.stroke_fill snowman_muffler
    end
  end
end

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

# グラフィックスの出力

page = PdfPage.add_to(document)
page.add_content do |content|
  # 矩形、楕円の出力
  graphic = PdfGraphic.new
  graphic.write_in(content) do |pen|
    basic_rect = PdfGraphic::Rectangle.new([2.cm, 19.cm], [5.cm, 17.cm])
    pen.stroke basic_rect

    round_rect = PdfGraphic::Rectangle.new([6.cm, 19.cm], [8.cm, 17.cm], round: 3.mm)
    pen.stroke round_rect

    oval = PdfGraphic::Oval.new([2.cm, 16.cm], [5.cm, 14.cm])
    pen.stroke oval

    circle = PdfGraphic::Oval.new([6.cm, 16.cm], [8.cm, 14.cm])
    pen.stroke circle
  end

  # 雪だるまの出力
  draw_snowman content, [3.5.cm, 12.cm], 3.cm, 0, PdfColor::Rgb.new(red: 1.0)

  # 雪だるまを回転させて出力
  7.times do |t|
    x = 2.cm * (6-t)/6 + 12.8.cm * t/6
    y = 9.cm
    rad = - Math::PI * t/3
    r = [1, 1, 0, 0, 0, 1, 1][t]
    g = [0, 1, 1, 1, 0, 0, 0][t]
    b = [0, 0, 0, 1, 1, 1, 0][t]
    color = PdfColor::Rgb.new(red: r, green: g, blue: b)
    draw_snowman content, [x, y], 1.8.cm, rad, color
  end
end

document.add_destination("Page1", PdfDestination.new(page, 0.mm, 210.mm))
document.add_destination("矩形", PdfDestination.new(page, 2.cm, 19.cm))
document.add_destination("雪だるま", PdfDestination.new(page, 2.cm, 13.5.cm))

# PNG画像の出力

page = PdfPage.add_to(document)
page.add_content do |content|
  # PNG画像の背景（マスクの確認用）
  graphic = PdfGraphic.new
  graphic.fill_color = PdfColor::Rgb.new green: 1, blue: 1
  graphic.write_in(content) do |pen|
    basic_rect = PdfGraphic::Rectangle.new([2.cm, 19.cm], [6.cm, 14.cm])
    pen.fill basic_rect
  end

  # 雪だるまのPNG画像
  image = PdfImage.new
  image.anchor = PdfImage::Anchor::CENTER
  image.dpi = 350
  image.write_in(content) do |pen|
    pen.paint snowman_png, x: 4.cm, y: 16.5.cm
  end
end

document.add_destination("Page2", PdfDestination.new(page, 0.mm, 210.mm))
document.add_destination("雪だるま（PNG画像）", PdfDestination.new(page, 2.cm, 19.cm))

# テキストの出力

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
      put_tex(pen, 14)
      pen.puts "グッバイしたい！"
    end
  end

  content.stack_graphic_state do
    content.move_origin 22.mm, 128.mm

    # レンダリングモードを変えて出力
    text = PdfText.new(pdf_font, 48)
    text.leading = 56
    text.rendering_mode = PdfText::RenderingMode::FILL_STROKE
    text.line_width = 1.5
    text.stroke_color = PdfColor::Rgb.new red: 1.0
    text.fill_color = PdfColor::Rgb.new red: 1.0, green: 1.0
    text.write_in(content) do |pen|
      put_tex(pen, 48)
      pen.puts "グッバイ"
      pen.puts "したい！"
    end
  end
end

document.add_destination("Page3", PdfDestination.new(page, 0.mm, 210.mm))
document.add_destination("テキスト", PdfDestination.new(page, 22.mm, 188.mm + 14.pt))
document.add_destination("TeXグッバイ（大）", PdfDestination.new(page, 22.mm, 128.mm + 48.pt))

# リンクの出力

# 簡易的な文字幅計算
def get_width(str, fontsize)
  str.each_char.map do |char|
    char.ascii_only? ? 0.5 : 1.0
  end.sum() * fontsize
end

page = PdfPage.add_to(document)
page.add_content do |content|
  content.stack_graphic_state do
    content.move_origin 22.mm, 188.mm

    # 内部リンク
    text = PdfText.new(pdf_font, 14)
    text.leading = 16
    text.fill_color = PdfColor::Rgb.new blue: 1.0
    text.write_in(content) do |pen|
      dests = [
        "Page1", "矩形", "雪だるま",
        "Page2", "雪だるま（PNG画像）",
        "Page3", "テキスト", "TeXグッバイ（大）",
      ]
      y_offset = 188.mm
      dests.each_with_index do |dest, t|
        str = "Link#{t}: #{dest}"
        width = get_width(str, 14)
        pen.puts str
        page.add_link(
          PdfInternalLink.new(
            dest,
            [22.mm, y_offset, 22.mm + width, y_offset + 14.pt],
            dest))
        y_offset -= 16.pt
      end
    end
  end

  # 外部リンク
  content.stack_graphic_state do
    content.move_origin 92.mm, 188.mm

    text = PdfText.new(pdf_font, 14)
    text.leading = 16
    text.fill_color = PdfColor::Rgb.new blue: 1.0
    text.write_in(content) do |pen|
      links = [
        {name: "Yahoo",
         uri: URI.parse("https://www.yahoo.co.jp/")},
        {name: "TeXグッバイ本",
         uri: URI.parse("https://www.yamaimo.dev/entry/TexGoodBye1")},
      ]
      y_offset = 188.mm
      links.each do |link|
        width = get_width(link[:name], 14)
        pen.puts link[:name]
        page.add_link(
          PdfExternalLink.new(
            link[:uri],
            [92.mm, y_offset, 92.mm + width, y_offset + 14.pt],
            link[:name]))
        y_offset -= 16.pt
      end
    end
  end
end

document.add_destination("Page4", PdfDestination.new(page, 0.mm, 210.mm))

# アウトラインの設定

page1_outline = PdfOutlineItem.add_to(document, "ページ1", "Page1")
PdfOutlineItem.add_to(page1_outline, "矩形", "矩形")
PdfOutlineItem.add_to(page1_outline, "雪だるま", "雪だるま")

page2_outline = PdfOutlineItem.add_to(document, "ページ2", "Page2")
PdfOutlineItem.add_to(page2_outline, "雪だるま（PNG画像）", "雪だるま（PNG画像）")

page3_outline = PdfOutlineItem.add_to(document, "ページ3", "Page3")
PdfOutlineItem.add_to(page3_outline, "テキスト", "テキスト")
PdfOutlineItem.add_to(page3_outline, "TeXグッバイ（大）", "TeXグッバイ（大）")

PdfOutlineItem.add_to(document, "ページ4", "Page4")

# PDFの出力

writer = PdfWriter.new("output_test.pdf")
writer.write(document)
