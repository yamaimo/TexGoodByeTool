# PDFドキュメント

require 'forwardable'

class PdfDocument

  extend Forwardable

  class DocCatalog

    def initialize(page_tree, named_destination, outline)
      @page_tree = page_tree
      @named_destination = named_destination
      @outline = outline
    end

    def attach_to(binder)
      @page_tree.attach_to(binder)
      @named_destination.attach_to(binder)
      @outline.attach_to(binder)

      doc_catalog_dict = {
        Type: :Catalog,
        Pages: binder.get_ref(@page_tree),
        Dests: binder.get_ref(@named_destination),
        Outlines: binder.get_ref(@outline),
      }
      binder.attach(self, doc_catalog_dict)
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

    def attach_to(binder)
      @resource.attach_to(binder)
      @pages.each {|page| page.attach_to(binder)}

      page_tree_dict = {
        Type: :Pages,
        Count: @pages.size,
        Kids: @pages.map{|page| binder.get_ref(page)},
        Resources: binder.get_ref(@resource),
        MediaBox: [0, 0, @page_width, @page_height],
      }
      binder.attach(self, page_tree_dict)
    end

  end

  class Resource

    def initialize
      @fonts = {}
      @images = {}
    end

    def add_font(pdf_font)
      @fonts[pdf_font.id.to_sym] = pdf_font
    end

    def add_image(pdf_image)
      @images[pdf_image.id.to_sym] = pdf_image
    end

    def attach_to(binder)
      @fonts.each {|id, font| font.attach_to(binder)}
      @images.each {|id, image| image.attach_to(binder)}

      resource_dict = {
        Font: @fonts.transform_values do |font|
          binder.get_ref(font)
        end,
        XObject: @images.transform_values do |image|
          binder.get_ref(image)
        end,
      }
      binder.attach(self, resource_dict)
    end

  end

  class NamedDestination

    def initialize
      @destinations = {}
    end

    def add_destination(name, pdf_destination)
      @destinations[name] = pdf_destination
    end

    def attach_to(binder)
      name_dest_dict = @destinations.transform_values do |dest|
        dest.to_a(binder)
      end
      binder.attach(self, name_dest_dict)
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
      @outline_items.each do |outline_item|
        outline_item.attach_to(binder)
      end

      outline_dict = {}
      unless @outline_items.empty?
        first_item = @outline_items[0]
        last_item = @outline_items[-1]
        outline_dict[:First] = binder.get_ref(first_item)
        outline_dict[:Last] = binder.get_ref(last_item)
      end
      binder.attach(self, outline_dict)
    end

  end

  class DocInfo

    def initialize
      @title = nil
      @subject = nil
      @keywords = nil
      @author = nil
      @create_time = nil
      @modify_time = nil
      @app = nil
    end

    attr_writer :title, :subject, :keywords, :author
    attr_writer :create_time, :modify_time, :app

    def attach_to(binder)
      create_time = @create_time || Time.now
      modify_time = @modify_time || Time.now

      doc_info_dict = {
        Producer: "TexGoodByeTool",
        CreationDate: create_time,
        ModDate: modify_time,
      }
      doc_info_dict[:Title] = @title if @title
      doc_info_dict[:Subject] = @subject if @subject
      doc_info_dict[:Keywords] = @keywords if @keywords
      doc_info_dict[:Author] = @author if @author
      doc_info_dict[:Creator] = @app if @app

      binder.attach(self, doc_info_dict)
    end

  end

  def initialize(page_width, page_height)
    @resource = Resource.new
    @page_tree = PageTree.new(page_width, page_height, @resource)
    @named_destination = NamedDestination.new
    @outline = Outline.new
    @root = DocCatalog.new(@page_tree, @named_destination, @outline)
    @info = DocInfo.new
  end

  attr_reader :root, :info

  def_delegators :@page_tree, :add_page

  def_delegators :@resource, :add_font, :add_image

  def_delegators :@named_destination, :add_destination

  def_delegators :@outline, :add_outline_item

  def_delegators :@info, :title=, :subject=, :keywords=, :author=
  def_delegators :@info, :create_time=, :modify_time=, :app=

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
      page_dict = {
        Type: :Page,
        Parent: binder.get_ref(@parent),
      }
      binder.attach(self, page_dict)
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
      font_dict = {
        Type: :Font,
        BaseFont: @name.to_sym,
      }
      binder.attach(self, font_dict)
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
      image_dict = {
        Type: :XObject,
        Subtype: :Image,
        Name: @name.to_sym,
      }
      binder.attach(self, image_dict)
    end

  end

  class PdfDestinationMock

    def initialize(page)
      @page = page
    end

    def to_a(binder)
      [binder.get_ref(@page), :XYZ, nil, nil, nil]
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
      outline_item_dict = {
        Title: @title,
        Parent: binder.get_ref(@parent),
      }
      outline_item_dict[:Prev] = binder.get_ref(@prev) if @prev
      outline_item_dict[:Next] = binder.get_ref(@next) if @next
      binder.attach(self, outline_item_dict)
    end

  end

  # A5
  using LengthExtension
  page_width = 148.mm
  page_height = 210.mm

  document = PdfDocument.new(page_width, page_height)
  document.title = "テスト"
  document.author = "やまいも"
  document.app = "vim"

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
  document.add_destination("ページ2", PdfDestinationMock.new(page2))

  document.add_outline_item(PdfOutlineItemMock.new("outline1"))
  document.add_outline_item(PdfOutlineItemMock.new("アウトライン2"))

  binder = PdfObjectBinder.new
  document.root.attach_to(binder)
  document.info.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
