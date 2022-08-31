# 組版ドキュメント

require 'set'

require_relative 'typeset_page'
require_relative 'pdf_document'
require_relative 'pdf_font'
require_relative 'pdf_page'

class TypesetDocument

  def initialize(width, height)
    @width = width
    @height = height
    @pages = []
    @fonts = Set.new
    @images = Set.new
  end

  attr_reader :width, :height

  def page_count
    @pages.size
  end

  def new_page(page_style)
    allocated_width = @width - page_style.margin.left - page_style.margin.right
    allocated_height = @height - page_style.margin.top - page_style.margin.bottom
    page = TypesetPage.new(self, page_style, allocated_width, allocated_height)
    @pages.push page
    page
  end

  def break_page
    # FIXME: スタイルを変えられる仕組みが必要
    last_page = @pages.last
    self.new_page(last_page.page_style)
  end

  def add_font(pdf_font)
    @fonts.add(pdf_font)
  end

  def add_image(pdf_image)
    @images.add(pdf_image)
  end

  def to_pdf_document
    pdf_document = PdfDocument.new(@width, @height)

    @fonts.each do |font|
      pdf_document.add_font(font)
    end

    @images.each do |image|
      pdf_document.add_image(image)
    end

    @pages.each do |page|
      pdf_page = PdfPage.add_to(pdf_document)
      pdf_page.add_content do |content|
        page.write_to(content)
      end
    end

    pdf_document
  end

end

if __FILE__ == $0
  # 後回し
end
