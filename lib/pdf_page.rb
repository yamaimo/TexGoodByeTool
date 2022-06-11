# PDFページ

require_relative 'pdf_text'

class PdfPage

  class Content

    def initialize
      @operations = []
    end

    attr_reader :operations

    def stack_graphic_state(&block)
      @operations.push "q"
      block.call
      @operations.push "Q"
    end

    def move_origin(x, y)
      @operations.push "1. 0. 0. 1. #{x} #{y} cm"
    end

    def add_text(&block)
      @operations.push "BT"

      text = PdfText.new(@operations)
      block.call(text)

      @operations.push "ET"
    end

    def attach_to(binder)
      stream = @operations.join("\n")
      length = stream.bytesize + "\n".bytesize

      binder.attach(self, {Length: length}, stream)
    end

  end

  def self.add_to(document)
    page = PdfPage.new
    document.add_page(page)
    page
  end

  def initialize
    @content = Content.new
    @parent = nil
  end

  def parent=(parent)
    @parent = parent
  end

  def add_content(&block)
    block.call(@content)
  end

  def attach_to(binder)
    @content.attach_to(binder)

    page_dict = {
      Type: :Page,
      Parent: binder.get_ref(@parent),
      Contents: [binder.get_ref(@content)],
    }
    binder.attach(self, page_dict)
  end

end

if __FILE__ == $0
  require_relative 'sfnt_font'
  require_relative 'pdf_font'
  require_relative 'length_extension'
  require_relative 'pdf_object_binder'

  if ARGV.empty?
    puts "[Font file list] ----------"
    puts SfntFont.list
    puts "---------------------------"
    raise "No font file is specified."
  end

  filename = ARGV[0]
  sfnt_font = SfntFont.load(filename)
  pdf_font = PdfFont.new(sfnt_font)

  class PdfDocumentMock

    def initialize
      @pages = []
      @resource = {}
      def @resource.add_font(pdf_font)
        self[pdf_font.id] = pdf_font
      end
      def @resource.get_font(id)
        self[id]
      end
    end

    attr_reader :resource

    def add_page(page)
      @pages.push page
      page.parent = self
    end

    def add_font(pdf_font)
      @resource.add_font(pdf_font)
    end

    def attach_to(binder)
      @pages.each{|page| page.attach_to(binder)}

      binder.attach(self, {Type: :Document})
    end

  end

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

  using LengthExtension

  document = PdfDocumentMock.new
  document.add_font(pdf_font)

  page = PdfPage.add_to(document)
  page.add_content do |content|
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

  binder = PdfObjectBinder.new
  document.attach_to(binder)

  binder.serialized_objects.each do |serialized_object|
    puts serialized_object
  end
end
