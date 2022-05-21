require 'erb'
require 'pathname'

require_relative 'lib/length_extension'
require_relative 'lib/markdown_parser'
require_relative 'lib/pdf_writer'

#--------------------
# マクロ
#--------------------

# 空行
def empty_line(count = 1)
  # 空の段落で空行の代わりにする
  "<p> </p>" * count
end

#--------------------
# 処理
#--------------------

def md2pdf(output, sources, style, fonts)
  # ソース結合
  markdown = sources.map do |source|
    File.read(source)
  end.join("\n\n")  # 各ファイル間に空行を1行入れておく

  # 前処理 (erb)
  markdown = ERB.new(markdown, trim_mode: "-").result

  # パース
  # Markdown -> 組版ドキュメント -> PDFドキュメント
  parser = MarkdownParser.new(style, fonts)
  typeset_document = parser.parse(markdown)
  pdf_document = typeset_document.to_pdf_document

  # 出力
  writer = PdfWriter.new(output)
  writer.write(pdf_document)
end
