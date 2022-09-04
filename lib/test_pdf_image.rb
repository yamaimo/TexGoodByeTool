# PNG画像のテスト出力

require_relative 'length_extension'
require_relative 'pdf_document'
require_relative 'pdf_page'
require_relative 'pdf_graphic'
require_relative 'pdf_image'
require_relative 'pdf_writer'

using LengthExtension

# A5
page_width = 148.mm
page_height = 210.mm
document = PdfDocument.new(page_width, page_height)

document.title = "PNG画像のテスト出力"
document.author = "やまいも"

snowman_png = PdfImage::Png.load('christmas_snowman.png')
document.add_image(snowman_png)

page = PdfPage.add_to(document)
page.add_content do |content|
  # PNG画像の背景（マスクの確認用）
  graphic_setting = PdfGraphic::Setting.new
  fill_color = PdfColor::Rgb.new green: 1, blue: 1
  graphic_setting.fill_color = fill_color
  graphic_setting.get_pen_for(content) do |pen|
    basic_rect = PdfGraphic::Rectangle.new([2.cm, 19.cm],
                                           [6.cm, 14.cm])
    pen.fill basic_rect
  end

  # 雪だるまのPNG画像
  image_setting = PdfImage::Setting.new
  image_setting.anchor = PdfImage::Anchor::CENTER
  image_setting.dpi = 350
  image_setting.get_pen_for(content) do |pen|
    pen.paint snowman_png, x: 4.cm, y: 16.5.cm
  end
end

writer = PdfWriter.new("image_test.pdf")
writer.write(document)
