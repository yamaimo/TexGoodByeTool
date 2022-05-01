# DOMから組版オブジェクトを組み立てる

require 'ox'

class DomHandler

  # 未登録のノードを処理する
  class UnknownNodeHandler

    def handle_node(node, typeset_document)
      unknown_value = node.is_a?(Ox::Node) ? node.value : node
      puts "[unknown] #{unknown_value}"
    end

  end

  def initialize
    @node_handlers = {}
    @text_handler = nil
    @page_handler = nil
    @unknown_node_handler = UnknownNodeHandler.new
  end

  def register_node_handler(tag, node_handler)
    @node_handlers[tag] = node_handler
    node_handler.dom_handler = self
  end

  def register_text_handler(text_handler)
    @text_handler = text_handler
    text_handler.dom_handler = self
  end

  def register_page_handler(page_handler)
    @page_handler = page_handler
  end

  def handle_dom(dom, typeset_document)
    dom.each do |node|
      dispatch_node_handling(node, typeset_document)
    end
  end

  def dispatch_node_handling(node, typeset_document)
    if node.is_a?(Ox::Node)
      tag = node.value
      node_handler = @node_handlers[tag] || @unknown_node_handler
      node_handler.handle_node(node, typeset_document)
    elsif node.is_a?(String)
      text_handler = @text_handler || @unknown_node_handler
      text_handler.handle_node(node, typeset_document)
    else
      @unknown_node_handler.handle_node(node.to_s, typeset_document)
    end
  end

  def create_new_page(typeset_document)
    @page_handler.create_new_page(typeset_document)
  end

  # フォントを設定してブロック処理をする
  # 改行の扱いを設定してブロック処理する
  # とかもあるとよさそう
  # dom_handler.with_font(font) do
  #   ...
  # end
  # みたいな

end

if __FILE__ == $0
  class PrintNodeHandler

    def self.add_to(dom_handler, value)
      if value == "text"
        text_handler = self.new
        dom_handler.register_text_handler(text_handler)
      else
        node_handler = self.new
        dom_handler.register_node_handler(value, node_handler)
      end
    end

    def initialize
      @dom_handler = nil
    end

    attr_accessor :dom_handler

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

  end

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

  dom_handler = DomHandler.new
  PrintNodeHandler.add_to(dom_handler, "h1")
  PrintNodeHandler.add_to(dom_handler, "p")
  PrintNodeHandler.add_to(dom_handler, "text")
  PrintPageHandler.add_to(dom_handler, "plain")

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
