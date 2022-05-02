# DOMから組版オブジェクトを組み立てる

require 'ox'

require_relative 'typeset_margin'
require_relative 'typeset_padding'
require_relative 'typeset_font'

class DomHandler

  # ハンドラー未登録の場合に処理をする
  class DefaultHandler

    def create_new_page(typeset_document)
      puts "[warning] page handler is not registered."
      typeset_document.new_page(TypesetMargin.zero_margin, TypesetPadding.zero_padding, 0)
    end

    def handle_node(node, typeset_document)
      puts "[warning] node handler for #{node.value} is not registered."
    end

    def handle_text(text, typeset_document, ignore_line_feed)
      puts "[warning] text handler is not registered."
    end

  end

  def initialize(default_sfnt_font, default_font_size)
    @page_handler = nil
    @node_handlers = {}
    @text_handler = nil
    @default_handler = DefaultHandler.new

    # FIXME: text handlerがボックスの設定を参照できるようにした方がよさそう
    # chain of responsibilityで上位に問い合わせていく
    default_font = TypesetFont.new(default_sfnt_font, default_font_size)
    @typeset_font_stack = [default_font]
    @ignore_line_feed = true
  end

  attr_accessor :ignore_line_feed

  def register_page_handler(page_handler)
    @page_handler = page_handler
  end

  def register_node_handler(tag, node_handler)
    @node_handlers[tag] = node_handler
  end

  def register_text_handler(text_handler)
    @text_handler = text_handler
  end

  def create_new_page(typeset_document)
    page_handler = @page_handler || @default_handler
    page_handler.create_new_page(typeset_document)
  end

  def handle_dom(dom, typeset_document)
    dom.each do |node|
      dispatch_node_handling(node, typeset_document)
    end
  end

  def dispatch_node_handling(node, typeset_document)
    if node.is_a?(Ox::Node)
      tag = node.value
      node_handler = @node_handlers[tag] || @default_handler
      node_handler.handle_node(node, typeset_document)
    elsif node.is_a?(String)
      text_handler = @text_handler || @default_handler
      text_handler.handle_text(node, typeset_document, @ignore_line_feed)
    else
      @unknown_node_handler.handle_node(node.to_s, typeset_document)
    end
  end

  def stack_font(typeset_font, &block)
    @typeset_font_stack.push typeset_font
    block.call
    @typeset_font_stack.pop
  end

  def current_font
    @typeset_font_stack[-1]
  end

end

if __FILE__ == $0
  class PrintPageHandler

    def self.add_to(dom_handler, style)
      page_handler = self.new(style)
      dom_handler.register_page_handler(page_handler)
    end

    def initialize(style)
      @style = style
    end

    def create_new_page(typeset_document)
      puts "[page] #{@style}"
    end

  end

  class PrintNodeHandler

    def self.add_to(dom_handler, value)
      if value == "text"
        text_handler = self.new(dom_handler)
        dom_handler.register_text_handler(text_handler)
      else
        node_handler = self.new(dom_handler)
        dom_handler.register_node_handler(value, node_handler)
      end
    end

    def initialize(dom_handler)
      @dom_handler = dom_handler
    end

    def handle_node(node, typeset_document)
      if node.is_a?(Ox::Node)
        if node.value == "h1"
          @dom_handler.create_new_page(typeset_document)
        end
        puts "[node] #{node.value}"
        node.each do |child|
          @dom_handler.dispatch_node_handling(child, typeset_document)
        end
      else
        puts "[text] #{node}"
      end
    end

    def handle_text(text, typeset_document, ignore_line_feed)
      handle_node(text, typeset_document)
    end

  end

  dom_handler = DomHandler.new(nil, nil) # ここではfontは使わない
  PrintPageHandler.add_to(dom_handler, "plain")
  PrintNodeHandler.add_to(dom_handler, "h1")
  PrintNodeHandler.add_to(dom_handler, "p")
  PrintNodeHandler.add_to(dom_handler, "text")

  dom = Ox.load(<<~END_OF_HTML)
    <body>
      <h1>hoge</h1>
      xxx
      <p>hugahuga</p>
      <h1>huga</h1>
      <p>huga<strong>hoge</strong>huga</p>
    </body>
  END_OF_HTML

  dom_handler.handle_dom(dom, nil)
end
