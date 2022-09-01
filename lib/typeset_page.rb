# 組版オブジェクト：ページ

require_relative 'typeset_body'
require_relative 'typeset_block'
require_relative 'typeset_margin'
require_relative 'typeset_padding'
require_relative 'block_style'

class TypesetPage
  # 子はTypesetBdobyで、これに#width, #height, #margin, #write_to(content)を要求する。
  # 親はTypesetDocumentで、これに#break_pageを要求する。

  def initialize(parent, page_style, allocated_width, allocated_height)
    @parent = parent
    @page_style = page_style
    @allocated_width = allocated_width
    @allocated_height = allocated_height
    @body = nil
    @footer = nil
  end

  attr_reader :page_style, :allocated_width, :allocated_height

  def width # いらないかも
    # FIXME: 自身のpadding, 子の間のmarginの計算が必要だけど後回し
    body_width = @body&.width || 0
    footer_width = @footer&.width || 0
    [body_width, footer_width].max
  end

  def height  # いらないかも
    # NOTE: 最後のボックスの下側マージンは無視
    # NOTE: 元はbodyの高さをpageの高さにしてた（改ページの判定のため）

    # FIXME: 自身のpadding, 子の間のmarginの計算が必要だけど後回し
    body_height = @body&.height || 0
    footer_height = @footer&.height || 0
    body_height + @page_style.to_footer_gap + footer_height
  end

  def new_body(text_style, line_gap)
    allocated_width = @allocated_width
    # FIXME: さらに自身のpadding, 子のmarginから幅を計算する必要があるが後回し
    allocated_height = @allocated_height
    # FIXME: さらに自身のpadding, 子のmarginから高さを計算する必要があるが後回し
    @body = TypesetBody.new(self, text_style, line_gap, allocated_width, allocated_height)
  end

  def new_footer(text_style)
    # FIXME: とりあえずの実装
    # フッターは一つのボックスとし、上下マージンは0、左右マージンはページと同じとする
    # そしてto_footer_gapが上パディング
    # 行送りは0
    allocated_footer_width = @allocated_width
    allocated_footer_height = @margin.bottom - @to_footer_gap
    footer_margin = TypesetMargin.new(left: @margin.left, right: @margin.right)
    footer_padding = TypesetPadding.new(top: @to_footer_gap)
    block_style = BlockStyle.new(margin: footer_margine, padding: footer_padding, line_gap: 0)
    @footer = TypesetBlock.new(self, block_style, text_style,
                               allocated_footer_width, allocated_footer_height)
  end

  def break_page
    new_page = @parent.break_page
    new_page.new_body(@body.text_style, @body.block_style.line_gap)
  end

  def write_to(content)
    upper_left_x = @page_style.margin.left
    upper_left_y = @page_style.margin.bottom + @allocated_height
    puts "TypesetPage#write_to (x: #{upper_left_x}, y: #{upper_left_y})"  # debug
    @body.write_to content, upper_left_x, upper_left_y

    if @footer
      content.move_origin @page_style.margin.left, @page_style.margin.bottom
      @footer.write_to content
    end
  end

#  # footerにページ番号を追加する処理
#  # ここかTypesetDocumentに必要
#  def add_page_number(typeset_document)
#    page_number = typeset_document.page_count
#    is_odd_page = page_number % 2 == 1
#    page_number_str = page_number.to_s
#
#    footer = typeset_document.current_page.footer
#    line = footer.new_line
#    font = TypesetFont.new(@style.footer_sfnt_font, @style.footer_font_size)
#    # 右揃えできるように、フォント設定は最後に左端に追加する
#
#    page_number_str.each_char do |char|
#      line.push font.get_typeset_char(char)
#    end
#
#    if is_odd_page
#      space = line.allocated_width - line.width
#      space_as_char_count = space / @style.footer_font_size
#      line.unshift font.get_space(space_as_char_count)
#    end
#    line.unshift font.get_font_set_operation
#  end

end

if __FILE__ == $0
  # 後回し
end
