# 設定用DSL

require_relative 'setting'
require_relative 'length_extension'
require_relative 'typeset_margin'
require_relative 'typeset_padding'

class SettingDsl

  using LengthExtension

  class TargetDsl

    def initialize(target_setting)
      @setting = target_setting
    end

    def output(path)
      @setting.output = path
    end

    def sources(*paths)
      paths.each do |path|
        @setting.add_source(path)
      end
    end

    def macro(path)
      @setting.macro = path
    end

    def style(name)
      @setting.style = name
    end

  end

  class StyleDsl

    class DocumentDsl

      def initialize(document_setting)
        @setting = document_setting
      end

      def paper(width: nil, height: nil)
        @setting.width = width if width
        @setting.height = height if height
      end

      def default_font(name: nil, size: nil)
        @setting.default_font_name = name if name
        @setting.default_font_size = size if size
      end

      def default_line_gap(size)
        @setting.default_line_gap = size
      end

    end

    class PageDsl

      def initialize(page_setting)
        @setting = page_setting
      end

      def margin(top: 0, right: 0, bottom: 0, left: 0)
        @setting.margin = TypesetMargin.new(top: top, right: right, bottom: bottom, left: left)
      end

      def padding(top: 0, right: 0, bottom: 0, left: 0)
        @setting.padding = TypesetPadding.new(top: top, right: right, bottom: bottom, left: left)
      end

      def to_footer_gap(size)
        @setting.to_footer_gap = size
      end

    end

    class BlockDsl

      def initialize(block_setting)
        @setting = block_setting
      end

      def font(name: nil, size: nil)
        @setting.font_name = name if name
        @setting.font_size = size if size
      end

      def line_gap(size)
        @setting.line_gap = size
      end

      def margin(top: 0, right: 0, bottom: 0, left: 0)
        @setting.margin = TypesetMargin.new(top: top, right: right, bottom: bottom, left: left)
      end

      def padding(top: 0, right: 0, bottom: 0, left: 0)
        @setting.padding = TypesetPadding.new(top: top, right: right, bottom: bottom, left: left)
      end

      def begin_new_page(bool)
        @setting.begin_new_page = bool
      end

      def indent(size)
        @setting.indent = size
      end

    end

    class InlineDsl

      def initialize(inline_setting)
        @setting = inline_setting
      end

      def font(name: nil)
        @setting.font_name = name if name
      end

      def ignore_line_feed(bool)
        @setting.ignore_line_feed = bool
      end

    end

    def initialize(style_setting)
      @setting = style_setting
    end

    def document(&block)
      dsl = DocumentDsl.new(@setting.document)
      dsl.instance_eval(&block)
    end

    def page(&block)
      dsl = PageDsl.new(@setting.page)
      dsl.instance_eval(&block)
    end

    def block(name, &block)
      @setting.blocks[name] ||= Setting::Style::Block.new
      dsl = BlockDsl.new(@setting.blocks[name])
      dsl.instance_eval(&block)
    end

    def inline(name, &block)
      @setting.inlines[name] ||= Setting::Style::Inline.new
      dsl = InlineDsl.new(@setting.inlines[name])
      dsl.instance_eval(&block)
    end

  end

  class FontDsl

    def initialize(font_setting)
      @setting = font_setting
    end

    def file(path, index: nil)
      @setting.file = path
      @setting.index = index if index
    end

  end

  def self.read(setting_str)
    setting = Setting.new
    dsl = self.new(setting)
    dsl.instance_eval(setting_str)
    setting.raise_if_invalid
    setting
  end

  def initialize(setting)
    @setting = setting
  end

  def target(name, &block)
    @setting.targets[name] ||= Setting::Target.new
    dsl = TargetDsl.new(@setting.targets[name])
    dsl.instance_eval(&block)
  end

  def style(name, &block)
    @setting.styles[name] ||= Setting::Style.new
    dsl = StyleDsl.new(@setting.styles[name])
    dsl.instance_eval(&block)
  end

  def font(name, &block)
    @setting.fonts[name] ||= Setting::Font.new
    dsl = FontDsl.new(@setting.fonts[name])
    dsl.instance_eval(&block)
  end

  def default_target(name)
    @setting.default_target = name
  end

end

if __FILE__ == $0
  # DSLでの設定記述
  setting_str = <<~END_OF_SETTING
    target "sample" do
      output "hogehuga.pdf"
      sources "hoge.md", "huga.md"
      macro "macro.rb"
      style "normal"
    end

    target "readme" do
      output "README.pdf"
      sources "README.md"
      style "normal"
    end

    style "normal" do
      document do
        paper width: 148.mm, height: 210.mm
        default_font name: "hiramin", size: 9.pt
        default_line_gap 6.pt
      end

      page do
        margin top: 1.5.cm, right: 2.cm, bottom: 1.5.cm, left: 2.cm
        to_footer_gap (0.8.cm - 9.pt)
      end

      block "h1" do
        margin bottom: 20.pt
        font name: "hiramin_bold", size: 16.pt
      end

      block "h2" do
        margin top: 20.pt, bottom: 14.pt
        font name: "hiramin_bold", size: 12.pt
      end

      block "p" do
        margin top: 7.pt, bottom: 7.pt
      end

      block "pre" do
        margin top: 15.pt, bottom: 15.pt
        line_gap 2.pt
      end

      inline "em" do
        font name: "hiramin_bold"
      end

      inline "strong" do
        font name: "hiramin_bold"
      end

      inline "code" do
        font name: "ricty"
      end
    end

    font "hiramin" do
      file "ヒラギノ明朝 ProN.ttc", index: 0
    end

    font "hiramin_bold" do
      file "ヒラギノ明朝 ProN.ttc", index: 2
    end

    font "ricty" do
      file "RictyDiminished-Regular.ttf"
    end

    default_target "sample"
  END_OF_SETTING

  # DSLでの設定記述を読んで設定取得
  setting = SettingDsl.read(setting_str)

  # 設定の参照

  # 表示用のモンキーパッチ
  class TypesetMargin
    def to_s
      "{top: #{@top}, right: #{@right}, bottom: #{@bottom}, left: #{@left}}"
    end
  end
  class TypesetPadding
    def to_s
      "{top: #{@top}, right: #{@right}, bottom: #{@bottom}, left: #{@left}}"
    end
  end

  setting.targets.each do |name, target|
    puts "target: #{name}"
    puts "  output : #{target.output}"
    puts "  sources: #{target.sources.join(', ')}"
    puts "  macro  : #{target.macro || '(none)'}"
    puts "  style  : #{target.style}"
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
      puts "      font name: #{block.font_name || '(default)'}"
      puts "      font size: #{block.font_size || '(default)'}"
      puts "      line gap : #{block.line_gap || '(default)'}"
      puts "      new page : #{block.begin_new_page?}"
      puts "      indent   : #{block.indent}"
    end

    puts "  inlines:"
    style.inlines.each do |tag, inline|
      puts "    #{tag}:"
      puts "      font name: #{inline.font_name || '(default)'}"
      puts "      ignore LF: #{inline.ignore_line_feed}"
    end
  end

  setting.fonts.each do |name, font|
    sfnt_font = font.sfnt_font
    puts "font: #{name} (#{sfnt_font.name})"
    puts "  file: #{font.file} (#{sfnt_font.path})"
    puts "  index: #{font.index}" if font.index
  end

  puts "default target: #{setting.default_target}"
end
