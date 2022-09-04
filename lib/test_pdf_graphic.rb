# グラフィックスのテスト出力

require_relative 'length_extension'
require_relative 'pdf_document'
require_relative 'pdf_page'
require_relative 'pdf_graphic'
require_relative 'pdf_writer'

using LengthExtension

# A5
page_width = 148.mm
page_height = 210.mm
document = PdfDocument.new(page_width, page_height)

document.title = "グラフィックスのテスト出力"
document.author = "やまいも"

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
    graphic_setting = PdfGraphic::Setting.new
    graphic_setting.line_cap = PdfGraphic::LineCapStyle::ROUND
    graphic_setting.line_join = PdfGraphic::LineJoinStyle::ROUND
    graphic_setting.get_pen_for(content) do |pen|
      pen.stroke snowman_body
      pen.stroke snowman_mouth
    end

    graphic_setting.fill_color = PdfColor::Rgb.new
    graphic_setting.get_pen_for(content) do |pen|
      snowman_eyes.each do |eye|
        pen.stroke_fill eye
      end
    end

    graphic_setting.fill_color = color
    graphic_setting.get_pen_for(content) do |pen|
      pen.stroke_fill snowman_hat
      pen.stroke_fill snowman_muffler
    end
  end
end

page = PdfPage.add_to(document)
page.add_content do |content|
  # 矩形、楕円の出力
  graphic_setting = PdfGraphic::Setting.new
  graphic_setting.get_pen_for(content) do |pen|
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

writer = PdfWriter.new("graphic_test.pdf")
writer.write(document)
