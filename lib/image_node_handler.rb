# img要素の処理

# FIXME: 暫定的な実装
# 本来imgはインライン要素だけど、
# ここではブロック要素のような扱いにしている。

require 'pathname'

require_relative 'pdf_image'

class ImageNodeHandler

  def self.add_to(dom_handler)
    handler = self.new(dom_handler)
    dom_handler.register_node_handler("img", handler)
    handler
  end

  def initialize(dom_handler)
    @dom_handler = dom_handler
    @images = {}
  end

  def handle_node(image_node, typeset_document)
    image_path = Pathname.new(image_node["src"])
    png_image = load_image(image_path)
    typeset_document.add_image(png_image)

    box = typeset_document.current_page.current_box

    # 暫定的にはboxは段落で、新しい行が1行だけ入ってる
    # その行を取り除き、image lineに置き換える
    box.pop
    box.new_image_line(png_image)

    # 改ページ処理
    if box.height > box.allocated_height
      last_line = box.pop
      new_page = @dom_handler.create_new_page(typeset_document)
      new_box = new_page.new_box(box.margin, box.padding, box.line_gap)
      # 画像の行だけなので再度入れるだけ
      new_box.push last_line
    end
  end

  private

  # 何度もロードしないようにキャッシュする
  def load_image(path)
    @images[path] ||= PdfImage::Png.load(path)
  end

end
