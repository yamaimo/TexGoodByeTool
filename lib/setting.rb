# 設定項目

require 'pathname'

require_relative 'sfnt_font'
require_relative 'sfnt_font_collection'
require_relative 'pdf_font'

class Setting

  # ビルド設定
  class Target

    def initialize
      @output = nil
      @sources = []
      @macro = nil
      @style_name = nil
    end

    attr_reader :output, :sources, :macro
    attr_accessor :style_name

    def output=(path)
      @output = Pathname.new(path)
    end

    def add_source(path)
      @sources.push Pathname.new(path)
    end

    def macro=(path)
      @macro = Pathname.new(path)
    end

    def raise_if_invalid
      raise "output is not specified." if @output.nil?
      raise "no source is specified." if @sources.empty?
      raise "style is not specified." if @style_name.nil?
    end

  end

  # スタイル設定
  class Style

    # ドキュメント
    class Document

      def initialize
        @width = nil
        @height = nil
        @default_font_name = nil
        @default_font_size = nil
        @default_line_gap = nil
      end

      attr_accessor :width, :height
      attr_accessor :default_font_name, :default_font_size
      attr_accessor :default_line_gap

      def raise_if_invalid
        raise "width is not specified." if @width.nil?
        raise "height is not specified." if @height.nil?
        raise "default font name is not specified." if @default_font_name.nil?
        raise "default font size is not specified." if @default_font_size.nil?
        raise "default line gap is not specified." if @default_line_gap.nil?
      end

    end

    # ページ
    class Page

      def initialize
        @margin = nil
        @padding = nil
        # FIXME: フッタは別設定にした方がいいかもしれない
        @to_footer_gap = nil
      end

      attr_accessor :margin, :padding, :to_footer_gap

    end

    # ブロック
    class Block

      def initialize
        @margin = nil
        @padding = nil
        @line_gap = nil
        @begin_new_page = nil
        @indent = nil
        @font_name = nil
        @font_size = nil
        @verbatim = nil
      end

      attr_accessor :margin, :padding, :line_gap
      attr_accessor :begin_new_page
      alias_method :begin_new_page?, :begin_new_page
      attr_accessor :indent
      attr_accessor :font_name, :font_size, :verbatim
      alias_method :verbatim?, :verbatim

    end

    # インライン
    class Inline

      def initialize
        @margin = nil
        @padding = nil
        @font_name = nil
        @font_size = nil
        @verbatim = nil
      end

      attr_accessor :margin, :padding
      attr_accessor :font_name, :font_size, :verbatim
      alias_method :verbatim?, :verbatim

    end

    def initialize
      @document = Document.new
      @page = Page.new
      @blocks = {}
      @inlines = {}
      set_default
    end

    attr_accessor :document, :page
    attr_reader :blocks, :inlines

    def raise_if_invalid
      @document.raise_if_invalid
    end

    private

    def set_default
      # ブロック
      (1..6).each do |level|
        @blocks["h#{level}".to_sym] = Block.new
      end
      @blocks[:p] = Block.new
      @blocks[:pre] = Block.new

      # インライン
      @inlines[:em] = Inline.new
      @inlines[:strong] = Inline.new
      @inlines[:code] = Inline.new

      # 要素ごとのデフォルトの設定
      @blocks[:h1].begin_new_page = true
      @blocks[:p].indent = 1
      @inlines[:code].verbatim = true
    end

  end

  # フォント設定
  class Font

    def initialize
      @file = nil
      @index = nil
      @pdf_font = nil
    end

    attr_accessor :file, :index

    def pdf_font
      @pdf_font ||= begin
        sfnt_font = if @index
                      SfntFontCollection.load(@file, @index)
                    else
                      SfntFont.load(@file)
                    end
        PdfFont.new(sfnt_font)
      end
    end

    def raise_if_invalid
      raise "file is not specified." if @file.nil?
    end

  end

  def initialize
    @targets = {}
    @styles = {}
    @fonts = {}
    @default_target = nil
  end

  attr_accessor :targets, :styles, :fonts
  attr_accessor :default_target

  def raise_if_invalid
    @targets.values.each(&:raise_if_invalid)
    @styles.values.each(&:raise_if_invalid)
    @fonts.values.each(&:raise_if_invalid)
    raise "default target is not specified." if @default_target.nil?
  end

end

if __FILE__ == $0
  require_relative 'margin'
  require_relative 'padding'
  require_relative 'length_extension'

  using LengthExtension

  # 設定の作成
  setting = Setting.new

  target = setting.targets[:sample] = Setting::Target.new
  target.output = "hogehuga.pdf"
  target.add_source("hoge.md")
  target.add_source("huga.md")
  target.macro = "macro.rb"
  target.style_name = :normal

  target = setting.targets[:readme] = Setting::Target.new
  target.output = "README.pdf"
  target.add_source("README.md")
  target.style_name = :normal

  style = setting.styles[:normal] = Setting::Style.new
  style.document.width = 148.mm
  style.document.height = 210.mm
  style.document.default_font_name = :hiramin
  style.document.default_font_size = 9.pt
  style.document.default_line_gap = 6.pt
  style.page.margin = Margin.new(top: 1.5.cm, right: 2.cm, bottom: 1.5.cm, left: 2.cm)
  style.page.to_footer_gap = 0.8.cm - 9.pt
  style.blocks[:h1].margin = Margin.new(bottom: 20.pt)
  style.blocks[:h1].font_name = :hiramin_bold
  style.blocks[:h1].font_size = 16.pt
  style.blocks[:h2].margin = Margin.new(top: 20.pt, bottom: 14.pt)
  style.blocks[:h2].font_name = :hiramin_bold
  style.blocks[:h2].font_size = 12.pt
  style.blocks[:p].margin = Margin.new(top: 7.pt, bottom: 7.pt)
  style.blocks[:pre].margin = Margin.new(top: 15.pt, bottom: 15.pt)
  style.blocks[:pre].line_gap = 2.pt
  style.inlines[:em].font_name = :hiramin_bold
  style.inlines[:strong].font_name = :hiramin_bold
  style.inlines[:code].font_name = :ricty

  font = setting.fonts[:hiramin] = Setting::Font.new
  font.file = "ヒラギノ明朝 ProN.ttc"
  font.index = 0

  font = setting.fonts[:hiramin_bold] = Setting::Font.new
  font.file = "ヒラギノ明朝 ProN.ttc"
  font.index = 2

  font = setting.fonts[:ricty] = Setting::Font.new
  font.file = "RictyDiminished-Regular.ttf"

  setting.default_target = :sample

  # 設定のチェック
  setting.raise_if_invalid

  # 設定の参照

  # 表示用のモンキーパッチ
  class Margin
    def to_s
      "{top: #{@top}, right: #{@right}, bottom: #{@bottom}, left: #{@left}}"
    end
  end
  class Padding
    def to_s
      "{top: #{@top}, right: #{@right}, bottom: #{@bottom}, left: #{@left}}"
    end
  end

  setting.targets.each do |name, target|
    puts "target: #{name}"
    puts "  output : #{target.output}"
    puts "  sources: #{target.sources.join(', ')}"
    puts "  macro  : #{target.macro || '(none)'}"
    puts "  style  : #{target.style_name}"
  end

  setting.styles.each do |name, style|
    puts "style: #{name}"
    puts "  document:"
    puts "    width            : #{style.document.width}"
    puts "    height           : #{style.document.height}"
    puts "    default font name: #{style.document.default_font_name}"
    puts "    default font size: #{style.document.default_font_size}"
    puts "    default line gap : #{style.document.default_line_gap}"
    puts "  page:"
    puts "    margin       : #{style.page.margin || '(default)'}"
    puts "    padding      : #{style.page.padding || '(default)'}"
    puts "    to footer gap: #{style.page.to_footer_gap}"

    puts "  blocks:"
    style.blocks.each do |tag, block|
      puts "    #{tag}:"
      puts "      margin   : #{block.margin || '(default)'}"
      puts "      padding  : #{block.padding || '(default)'}"
      puts "      line gap : #{block.line_gap || '(default)'}"
      puts "      new page : #{block.begin_new_page?}"
      puts "      indent   : #{block.indent}"
      puts "      font name: #{block.font_name || '(default)'}"
      puts "      font size: #{block.font_size || '(default)'}"
      puts "      verbatim : #{block.verbatim? || '(default)'}"
    end

    puts "  inlines:"
    style.inlines.each do |tag, inline|
      puts "    #{tag}:"
      puts "      margin   : #{inline.margin || '(default)'}"
      puts "      padding  : #{inline.padding || '(default)'}"
      puts "      font name: #{inline.font_name || '(default)'}"
      puts "      font size: #{inline.font_size || '(default)'}"
      puts "      verbatim : #{inline.verbatim? || '(default)'}"
    end
  end

  setting.fonts.each do |name, font|
    pdf_font = font.pdf_font
    puts "font: #{name} (#{pdf_font.id})"
    puts "  file: #{font.file}"
    puts "  index: #{font.index}" if font.index
  end

  puts "default target: #{setting.default_target}"
end
