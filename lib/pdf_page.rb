# PDFページ

require_relative 'pdf_text'

class PdfPage

  class Content

    def initialize(resource)
      @resource = resource
      @operations = []
    end

    def stack_origin(&block)
      @operations.push "q"
      block.call
      @operations.push "Q"
    end

    def move_origin(x, y)
      @operations.push "1. 0. 0. 1. #{x} #{y} cm"
    end

    def add_text(&block)
      @operations.push "BT"

      text = PdfText.new(@resource, @operations)
      block.call(text)

      @operations.push "ET"
    end

    def attach_content_to(pool)
      stream = @operations.join("\n")
      length = stream.bytesize + "\n".bytesize

      pool.attach_content(self, <<~END_OF_CONTENT)
        <<
          /Length #{length}
        >>
        stream
        #{stream}
        endstream
      END_OF_CONTENT
    end

  end

  def self.add_to(document)
    page = PdfPage.new
    document.add_page(page)
    page
  end

  def initialize
    @parent = nil
    @content = nil
  end

  def parent=(parent)
    @parent = parent
    @content = Content.new(@parent.resource)
  end

  def add_content(&block)
    block.call(@content)
  end

  def attach_content_to(pool)
    @content.attach_content_to(pool)

    pool.attach_content(self, <<~END_OF_PAGE)
      <<
        /Type /Page
        /Parent #{pool.get_ref(@parent)}
        /Contents [#{pool.get_ref(@content)}]
      >>
    END_OF_PAGE
  end

end

if __FILE__ == $0
  require_relative 'sfnt_font'
  require_relative 'pdf_font'
  require_relative 'length_extension'
  require_relative 'pdf_object_pool'

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

    def attach_content_to(pool)
      @pages.each{|page| page.attach_content_to(pool)}

      pool.attach_content(self, <<~END_OF_DOCUMENT)
        <<
          /Type /Document
        >>
      END_OF_DOCUMENT
    end

  end

  using LengthExtension

  document = PdfDocumentMock.new
  document.add_font(pdf_font)

  page = PdfPage.add_to(document)
  page.add_content do |content|
    content.move_origin 22.mm, 188.mm
    content.add_text do |text|
      text.set_font pdf_font.id, 14
      text.set_leading 16
      ["ABCDE", "あいうえお", "斉斎齊齋", "\u{20B9F}\u{20D45}\u{20E6D}"].each do |str|
        text.puts str
      end
      text.puts
      text.puts "TeXグッバイしたい！"
    end
  end

  pool = PdfObjectPool.new
  document.attach_content_to(pool)

  pool.contents.each do |content|
    puts content
  end
end
