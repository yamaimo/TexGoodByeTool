# DOMから組版オブジェクトを組み立てる

require 'ox'

class DomHandler

  # ハンドラー未登録の場合に処理をする
  class DefaultHandler

    def handle_node(node, parent, document)
      puts "[warning] node handler for #{node.value} is not registered."
    end

    def handle_text(text_str, parent, document)
      puts "[warning] text handler is not registered."
    end

  end

  def initialize
    @node_handlers = {}
    @text_handler = nil
    @default_handler = DefaultHandler.new
  end

  def register_node_handler(tag, node_handler)
    @node_handlers[tag.to_sym] = node_handler
  end

  def register_text_handler(text_handler)
    @text_handler = text_handler
  end

  def handle_dom(dom, typeset_body, typeset_document)
    dom.each do |node|
      dispatch_node_handling(node, typeset_body, typeset_document)
      # 改ページしてる可能性があるので、最新のボディを取得する
      typeset_body = typeset_body.latest
    end
  end

  def dispatch_node_handling(node, typeset_parent, typeset_document)
    if node.is_a?(Ox::Node)
      tag = node.value.to_sym
      node_handler = @node_handlers[tag] || @default_handler
      node_handler.handle_node(node, typeset_parent, typeset_document)
    elsif node.is_a?(String)
      text_handler = @text_handler || @default_handler
      text_handler.handle_text(node, typeset_parent, typeset_document)
    else
      @unknown_node_handler.handle_node(node.to_s, typeset_parent, typeset_document)
    end
  end

end

if __FILE__ == $0
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

    def handle_node(node, typeset_parent, typeset_document)
      if node.is_a?(Ox::Node)
        puts "[node] #{node.value}"
        node.each do |child|
          @dom_handler.dispatch_node_handling(child, node, typeset_document)
        end
      else
        puts "[text] #{node}"
      end
    end

    def handle_text(text_str, typeset_parent, typeset_document)
      handle_node(text_str, typeset_parent, typeset_document)
    end

  end

  dom_handler = DomHandler.new
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

  body = Object.new
  def body.latest
    self
  end

  dom_handler.handle_dom(dom, body, nil)
end
