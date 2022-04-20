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

  # フォントを設定してブロック処理をする
  # 改行の扱いを設定してブロック処理する
  # とかもあるとよさそう
  # dom_handler.with_font(font) do
  #   ...
  # end
  # みたいな

end

if __FILE__ == $0
  class PrintHandler

    def self.add_to_dom_handler(dom_handler, value)
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
        puts "[node] #{node.value}"
        node.each do |child|
          @dom_handler.dispatch_node_handling(child, typeset_document)
        end
      else
        puts "[text] #{node}"
      end
    end

  end

  dom_handler = DomHandler.new
  PrintHandler.add_to_dom_handler(dom_handler, "h1")
  PrintHandler.add_to_dom_handler(dom_handler, "p")
  PrintHandler.add_to_dom_handler(dom_handler, "text")

  dom = Ox.load(<<~END_OF_HTML)
    <body>
      <h1>hoge</h1>
      xxx
      <p>hugahuga</p>
      <p>huga<strong>hoge</strong>huga</p>
    </body>
  END_OF_HTML

  dom_handler.handle_dom(dom, nil)
end
