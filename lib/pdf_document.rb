# PDFドキュメント

class PdfDocument

  class DocCatalog

    def initialize(page_tree, named_destination, outline)
      @page_tree = page_tree
      @named_destination = named_destination
      @outline = outline
    end

    attr_reader :page_tree
    attr_reader :named_destination
    attr_reader :outline

    def attach_to(binder)
      @page_tree.attach_to(binder)
      @named_destination.attach_to(binder)
      @outline.attach_to(binder)

      binder.attach(self, <<~END_OF_DOC_CATALOG)
        <<
          /Type /Catalog
          /Pages #{binder.get_ref(@page_tree)}
          /Dests #{binder.get_ref(@named_destination)}
          /Outlines #{binder.get_ref(@outline)}
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

    def add_page(pdf_page)
      @pages.push pdf_page
      pdf_page.parent = self
    end

    attr_reader :resource

    def attach_to(binder)
      @resource.attach_to(binder)
      @pages.each {|page| page.attach_to(binder)}

      binder.attach(self, <<~END_OF_PAGE_TREE)
        <<
          /Type /Pages
          /Count #{@pages.size}
          /Kids [#{@pages.map{|page| binder.get_ref(page)}.join(' ')}]
          /Resources #{binder.get_ref(@resource)}
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

    def attach_to(binder)
      @fonts.each {|id, font| font.attach_to(binder)}
      font_entries = @fonts.map{|id, font| "/#{id} #{binder.get_ref(font)}"}.join(' ')

      @images.each {|id, image| image.attach_to(binder)}
      image_entries = @images.map{|id, image| "/#{id} #{binder.get_ref(image)}"}.join(' ')

      binder.attach(self, <<~END_OF_RESOURCE)
        <<
          /Font << #{font_entries} >>
          /XObject << #{image_entries} >>
        >>
      END_OF_RESOURCE
    end

  end

  class NamedDestination

    def initialize
      @destination = {}
    end

    def add_destination(name, pdf_destination)
      # nameはエンコードが必要な文字が含まれていないこと
      # （あとで修正したい）
      @destination[name] = pdf_destination
    end

    def attach_to(binder)
      name_dest_lines = @destination.map do |name, dest|
        "  /#{name} #{dest.to_serialized_data(binder)}"
      end.join("\n")

      binder.attach(self, <<~END_OF_NAMED_DESTINATION)
        <<
        #{name_dest_lines}
        >>
      END_OF_NAMED_DESTINATION
    end

  end

  class Outline

    def initialize
      @outline_items = []
    end

    def add_outline_item(pdf_outline_item)
      prev_item = nil
      unless @outline_items.empty?
        prev_item = @outline_items[-1]
        prev_item.next = pdf_outline_item
      end

      pdf_outline_item.parent = self
      pdf_outline_item.prev = prev_item

      @outline_items.push pdf_outline_item
    end

    def attach_to(binder)
      if @outline_items.empty?
        binder.attach(self, "<< >>")
      else
        @outline_items.each do |outline_item|
          outline_item.attach_to(binder)
        end

        first_item = @outline_items[0]
        last_item = @outline_items[-1]

        binder.attach(self, <<~END_OF_OUTLINE)
          <<
            /First #{binder.get_ref(first_item)}
            /Last #{binder.get_ref(last_item)}
          >>
        END_OF_OUTLINE
      end
    end

  end

  def initialize(page_width, page_height)
    resource = Resource.new
    page_tree = PageTree.new(page_width, page_height, resource)
    named_destination = NamedDestination.new
    outline = Outline.new
    @root = DocCatalog.new(page_tree, named_destination, outline)
  end

  attr_reader :root

  # FIXME: 以下は委譲にしたい
  # rootからreaderを取り除いて、各オブジェクトをdocumentで保持
  # pdf_pageで下のオブジェクトを使ってるところがあるので、
  # そこはdocumentから呼び出すようにする必要がある

  def add_page(pdf_page)
    @root.page_tree.add_page(pdf_page)
  end

  def add_font(pdf_font)
    @root.page_tree.resource.add_font(pdf_font)
  end

  def add_image(pdf_image)
    @root.page_tree.resource.add_image(pdf_image)
  end

  def add_destination(name, pdf_destination)
    @root.named_destination.add_destination(name, pdf_destination)
  end

  def add_outline_item(pdf_outline_item)
    @root.outline.add_outline_item(pdf_outline_item)
  end

end

if __FILE__ == $0
  require_relative 'length_extension'
  require_relative 'pdf_object_binder'

  class PdfPageMock

    def initialize
      @parent = nil
    end

    attr_writer :parent

    def attach_to(binder)
      binder.attach(self, <<~END_OF_PAGE)
        <<
          /Type /Page
          /Parent #{binder.get_ref(@parent)}
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

    def attach_to(binder)
      binder.attach(self, <<~END_OF_FONT)
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

    def attach_to(binder)
      binder.attach(self, <<~END_OF_IMAGE)
        <<
          /Type /XObject
          /Subtype /Image
          /Name /#{@name}
        >>
      END_OF_IMAGE
    end

  end

  class PdfDestinationMock

    def initialize(page)
      @page = page
    end

    def to_serialized_data(binder)
      "[#{binder.get_ref(@page)} /XYZ null null null]"
    end

  end

  class PdfOutlineItemMock

    def initialize(title)
      @title = title
      @parent = nil
      @prev = nil
      @next = nil
    end

    attr_writer :parent, :prev, :next

    def attach_to(binder)
      # FIXME: PDF用の基本型を作った方がよさそう
      bros_info = ""
      bros_info += "  /Prev #{binder.get_ref(@prev)}\n" if @prev
      bros_info += "  /Next #{binder.get_ref(@next)}\n" if @next

      binder.attach(self, <<~END_OF_OUTLINE_ITEM)
        <<
          /Title (#{@title})
          /Parent #{binder.get_ref(@parent)}
        #{bros_info}>>
      END_OF_OUTLINE_ITEM
    end

  end

  # A5
  using LengthExtension
  page_width = 148.mm
  page_height = 210.mm

  document = PdfDocument.new(page_width, page_height)

  page1 = PdfPageMock.new
  page2 = PdfPageMock.new
  document.add_page(page1)
  document.add_page(page2)

  document.add_font(PdfFontMock.new('test1'))
  document.add_font(PdfFontMock.new('test2'))
  document.add_font(PdfFontMock.new('test3'))

  document.add_image(PdfImageMock.new('image1'))
  document.add_image(PdfImageMock.new('image2'))

  document.add_destination("page1", PdfDestinationMock.new(page1))
  document.add_destination("page2", PdfDestinationMock.new(page2))

  document.add_outline_item(PdfOutlineItemMock.new("outline1"))
  document.add_outline_item(PdfOutlineItemMock.new("outline2"))

  binder = PdfObjectBinder.new
  document.root.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
