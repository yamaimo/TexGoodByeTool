# PDFドキュメント

class PdfDocument

  class DocCatalog

    def initialize(page_tree)
      @page_tree = page_tree
    end

    attr_reader :page_tree

    def attach_content_to(pool)
      @page_tree.attach_content_to(pool)

      pool.attach_content(self, <<~END_OF_DOC_CATALOG)
        <<
          /Type /Catalog
          /Pages #{pool.get_ref(@page_tree)}
        >>
      END_OF_DOC_CATALOG
    end

  end

  class PageTree

    def initialize(page_width, page_height, resource)
      @page_width = page_width
      @page_height = page_height
      @resource = resource
      @pages = []
    end

    def add_page(page)
      @pages.push page
      page.parent = self
    end

    attr_reader :resource

    def attach_content_to(pool)
      @resource.attach_content_to(pool)
      @pages.each {|page| page.attach_content_to(pool)}

      pool.attach_content(self, <<~END_OF_PAGE_TREE)
        <<
          /Type /Pages
          /Count #{@pages.size}
          /Kids [#{@pages.map{|page| pool.get_ref(page)}.join(' ')}]
          /Resources #{pool.get_ref(@resource)}
          /MediaBox [0 0 #{@page_width} #{@page_height}]
        >>
      END_OF_PAGE_TREE
    end

  end

  class Resource

    def initialize
      @fonts = {}
      @images = {}
    end

    def add_font(pdf_font)
      @fonts[pdf_font.id] = pdf_font
    end

    def get_font(id)
      @fonts[id]
    end

    def add_image(pdf_image)
      @images[pdf_image.id] = pdf_image
    end

    def get_image(id)
      @images[id]
    end

    def attach_content_to(pool)
      @fonts.each {|id, font| font.attach_content_to(pool)}
      font_entries = @fonts.map{|id, font| "/#{id} #{pool.get_ref(font)}"}.join(' ')

      @images.each {|id, image| image.attach_content_to(pool)}
      image_entries = @images.map{|id, image| "/#{id} #{pool.get_ref(image)}"}.join(' ')

      pool.attach_content(self, <<~END_OF_RESOURCE)
        <<
          /Font << #{font_entries} >>
          /XObject << #{image_entries} >>
        >>
      END_OF_RESOURCE
    end

  end

  def initialize(page_width, page_height)
    resource = Resource.new
    page_tree = PageTree.new(page_width, page_height, resource)
    @root = DocCatalog.new(page_tree)
  end

  attr_reader :root

  def add_page(pdf_page)
    @root.page_tree.add_page(pdf_page)
  end

  def add_font(pdf_font)
    @root.page_tree.resource.add_font(pdf_font)
  end

  def add_image(pdf_image)
    @root.page_tree.resource.add_image(pdf_image)
  end

end

if __FILE__ == $0
  require_relative 'length_extension'
  require_relative 'pdf_object_pool'

  class PdfPageMock

    def initialize
      @parent = nil
    end

    attr_writer :parent

    def attach_content_to(pool)
      pool.attach_content(self, <<~END_OF_PAGE)
        <<
          /Type /Page
          /Parent #{pool.get_ref(@parent)}
        >>
      END_OF_PAGE
    end

  end

  class PdfFontMock

    def initialize(name)
      @name = name
    end

    def id
      "Font#{self.object_id}"
    end

    def attach_content_to(pool)
      pool.attach_content(self, <<~END_OF_FONT)
        <<
          /Type /Font
          /BaseFont /#{@name}
        >>
      END_OF_FONT
    end

  end

  class PdfImageMock

    def initialize(name)
      @name = name
    end

    def id
      "Image#{self.object_id}"
    end

    def attach_content_to(pool)
      pool.attach_content(self, <<~END_OF_IMAGE)
        <<
          /Type /XObject
          /Subtype /Image
          /Name /#{@name}
        >>
      END_OF_IMAGE
    end

  end

  # A5
  using LengthExtension
  page_width = 148.mm
  page_height = 210.mm

  document = PdfDocument.new(page_width, page_height)
  document.add_page(PdfPageMock.new)
  document.add_page(PdfPageMock.new)
  document.add_font(PdfFontMock.new('test1'))
  document.add_font(PdfFontMock.new('test2'))
  document.add_font(PdfFontMock.new('test3'))
  document.add_image(PdfImageMock.new('image1'))
  document.add_image(PdfImageMock.new('image2'))

  pool = PdfObjectPool.new
  document.root.attach_content_to(pool)

  pool.contents.each do |content|
    puts content
  end
end
