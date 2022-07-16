# はじめてのPDF出力

require_relative 'length_extension'
require_relative 'pdf_writer'

class HelloPdfDocument

  using LengthExtension

  def initialize
    @root = Object.new  # ドキュメントカタログ
    @info = Object.new  # ドキュメント辞書

    # rootとinfoにattach_to(binder)を定義しておく
    define_attach_to
  end

  attr_reader :root, :info

  private

  def define_attach_to
    # ドキュメントカタログのattach_to(binder)を実装
    def @root.attach_to(binder)
      # A5
      page_width = 148.mm
      page_height = 210.mm

      # DOMの各要素
      page_tree = Object.new
      resource = Object.new
      font = Object.new
      page = Object.new
      content = Object.new

      # ドキュメントカタログ
      binder.attach(self, {
        Type: :Catalog,
        Pages: binder.get_ref(page_tree),
      })

      # ページツリー
      binder.attach(page_tree, {
        Type: :Pages,
        Count: 1,
        Resources: binder.get_ref(resource),
        Kids: [binder.get_ref(page)],
        MediaBox: [0, 0, page_width, page_height],
      })

      # リソース
      binder.attach(resource, {
        Font: {Font0: binder.get_ref(font)},
      })

      # フォント
      binder.attach(font, {
        Type: :Font,
        BaseFont: "Times-Roman".to_sym,
        Subtype: :Type1
      })

      # ページ
      binder.attach(page, {
        Type: :Page,
        Parent: binder.get_ref(page_tree),
        Contents: binder.get_ref(content),
      })

      # コンテンツ
      stream = <<~END_OF_STREAM
        1. 0. 0. 1. #{2.cm} #{17.cm} cm
        BT
        /Font0 36. Tf
        48 TL
        (Hello, PDF!) Tj T*
        (Goodbye, ) Tj
        (T) Tj
        [166.7] TJ
        -9 Ts
        (E) Tj
        0 Ts
        [125.0] TJ
        (X!!!) Tj
        ET
      END_OF_STREAM
      length = stream.bytesize
      binder.attach(content, {Length: length}, stream.chomp)
    end

    # ドキュメント情報のattach_to(binder)を実装
    def @info.attach_to(binder)
      binder.attach(self, {})
    end
  end

end

document = HelloPdfDocument.new

writer = PdfWriter.new("hello.pdf")
writer.write(document)
