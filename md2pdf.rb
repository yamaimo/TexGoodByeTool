require 'pathname'

require_relative 'lib/length_extension'
require_relative 'lib/macro_processor'
require_relative 'lib/markdown_parser'
require_relative 'lib/pdf_writer'

#--------------------
# 処理
#--------------------

def md2pdf(output, sources, macro, style, fonts)
  macro_code = macro ? File.read(macro) : ""
  macro_processor = MacroProcessor.new(macro_code)

  # マクロ評価、ソース結合
  markdown = sources.map do |source|
    template = File.read(source)
    macro_processor.process(template)
  end.join("\n\n")  # 各ファイル間に空行を1行入れておく

  # パース
  # Markdown -> 組版ドキュメント -> PDFドキュメント
  parser = MarkdownParser.new(style, fonts)
  typeset_document = parser.parse(markdown)
  pdf_document = typeset_document.to_pdf_document

  # 出力
  writer = PdfWriter.new(output)
  writer.write(pdf_document)
end
