# 組版ドキュメント

require 'forwardable'
require 'set'

require_relative 'typeset_page'
require_relative 'pdf_document'
require_relative 'pdf_font'
require_relative 'pdf_page'

class TypesetDocument

  extend Forwardable

  def initialize(width, height)
    @width = width
    @height = height
    @pages = []
    @fonts = Set.new
    @images = Set.new
  end

  attr_reader :width, :height

  def_delegators :@pages, :push, :pop, :unshift, :shift, :empty?

  def page_count
    @pages.size
  end

  def new_page(margin, padding, to_footer_gap)
    allocated_page_width = @width - margin.left - margin.right
    allocated_page_height = @height - margin.top - margin.bottom
    page = TypesetPage.new(allocated_page_width, allocated_page_height, margin, padding, to_footer_gap)
    @pages.push page
    page
  end

  def current_page
    @pages[-1]
  end

  def add_font(sfnt_font)
    @fonts.add(sfnt_font)
  end

  def add_image(pdf_image)
    @images.add(pdf_image)
  end

  def to_pdf_document
    pdf_document = PdfDocument.new(@width, @height)

    @fonts.each do |font|
      pdf_font = PdfFont.new(font)
      pdf_document.add_font(pdf_font)
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
  require_relative 'sfnt_font'
  require_relative 'typeset_font'
  require_relative 'typeset_margin'
  require_relative 'typeset_padding'
  require_relative 'typeset_box'
  require_relative 'pdf_object_binder'

  sfnt_font = SfntFont.load('ipaexm.ttf')
  font_size = 14
  line_gap = font_size / 2

  typeset_font = TypesetFont.new(sfnt_font, font_size)

  document_width = 200
  document_height = 500

  document = TypesetDocument.new(document_width, document_height)

  document.add_font(sfnt_font)

  page_margin = TypesetMargin.new(top: 20, right: 20, bottom: 20, left: 20)
  page_padding = TypesetPadding.new(top: 10, right: 10, bottom: 10, left: 10)

  page = document.new_page(page_margin, page_padding, 0)

  box_margin = TypesetMargin.new
  box_padding = TypesetPadding.new(top: 10, right: 10, bottom: 10, left: 10)

  box1 = page.new_box(box_margin, box_padding, line_gap)

  ["ABCDEあいうえお", "ほげほげ", "TeXグッバイしたい！"].each do |chars|
    line = box1.new_line
    chars.each_char do |char|
      line.push typeset_font.get_typeset_char(char)
    end
  end
  last_line = box1.pop

  box2 = page.new_box(box_margin, box_padding, line_gap)
  box2.push last_line

  pdf_document = document.to_pdf_document

  binder = PdfObjectBinder.new
  pdf_document.root.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
