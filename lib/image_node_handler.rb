# img要素の処理

require 'pathname'

require_relative 'pdf_image'

class ImageNodeHandler

  def self.add_to(dom_handler)
    handler = self.new(dom_handler)
    dom_handler.register_node_handler(:img, handler)
    handler
  end

  def initialize(dom_handler)
    @dom_handler = dom_handler
    @images = {}
  end

  def handle_node(image_node, parent, document)
    image_path = Pathname.new(image_node["src"])
    png_image = load_image(image_path, document)

    if parent.is_a?(TypesetBody) || parent.is_a?(TypesetBlock)
      parent = parent.current_line
    end

    # FIXME: 幅が足りない場合に先に改行が必要かもしれない
    # ただ、元々幅が足りない場合がややこしいので、今は単に追加する
    parent.new_image(png_image)
  end

  private

  # 何度もロードしないようにキャッシュする
  def load_image(path, document)
    @images[path] ||= begin
      png_image = PdfImage::Png.load(path)
      document.add_image(png_image)
      png_image
    end
  end

end
