require 'erb'
require 'pathname'

require_relative 'lib/length_extension'
require_relative 'lib/sfnt_font_collection'
require_relative 'lib/sfnt_font'
require_relative 'lib/typeset_margin'
require_relative 'lib/markdown_parser'
require_relative 'lib/pdf_writer'

using LengthExtension

#--------------------
# 設定
#--------------------

# 用紙(A5)
page_width = 148.mm
page_height = 210.mm
page_margin = TypesetMargin.new(top: 1.5.cm, right: 2.cm, bottom: 1.5.cm, left: 2.cm) # 柱は入れない
to_footer_gap = 0.8.cm - 9.pt

# フォント
default_font = SfntFontCollection.load("ヒラギノ明朝 ProN.ttc", 0)
bold_font = SfntFontCollection.load("ヒラギノ明朝 ProN.ttc", 2)
typewriter_font = SfntFont.load('RictyDiminished-Regular.ttf')
# typewriter_font = SfntFont.load("Monaco_converted.ttf") # FIXME: rescue_font対応したらこっちを使いたい

font_size = 9.pt
line_gap = 6.pt

# 章見出し
chapter_header_margin = TypesetMargin.new(bottom: 20.pt)
chapter_header_font = bold_font
chapter_header_font_size = 16.pt

# 節見出し
section_header_margin = TypesetMargin.new(top: 20.pt, bottom: 14.pt)
section_header_font = bold_font
section_header_font_size = 12.pt

# 段落
paragraph_margin = TypesetMargin.new(top: 7.pt, bottom: 7.pt)

# コード
preformatted_margin = TypesetMargin.new(top: 15.pt, bottom: 15.pt)
preformatted_line_gap = 2.pt

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

output = ARGV.shift
sources = ARGV

markdown = sources.map do |source|
  File.read(source)
end.join("\n\n")  # 空行を1行入れておく

# erbで処理しておく
markdown = ERB.new(markdown, trim_mode: "-").result

parser = MarkdownParser.new(page_width, page_height, default_font, font_size, line_gap)
parser.page_margin = page_margin
parser.to_footer_gap = to_footer_gap
parser.set_margin "h1", chapter_header_margin
parser.set_sfnt_font "h1", chapter_header_font
parser.set_font_size "h1", chapter_header_font_size
parser.set_margin "h2", section_header_margin
parser.set_sfnt_font "h2", section_header_font
parser.set_font_size "h2", section_header_font_size
parser.set_margin "p", paragraph_margin
parser.set_margin "pre", preformatted_margin
parser.set_line_gap "pre", preformatted_line_gap
parser.set_sfnt_font "em", bold_font
parser.set_sfnt_font "strong", bold_font
parser.set_sfnt_font "code", typewriter_font

typeset_document = parser.parse(markdown)
pdf_document = typeset_document.to_pdf_document

writer = PdfWriter.new(output)
writer.write(pdf_document)
