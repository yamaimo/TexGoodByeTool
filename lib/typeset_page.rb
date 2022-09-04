# 組版オブジェクト：ページ

require_relative 'typeset_body'

class TypesetPage
  # FIXME: このコメントを不要にしたい（ちゃんと整理できてない）
  # child: TypesetBody
  #   require: #block_style, #text_style, #write_to
  #   required: #break_page
  # parent: TypesetDocument
  #   require: #break_page, #page_count
  #   required: #page_style

  def initialize(parent, page_style, width, height)
    @parent = parent
    @page_style = page_style
    @width = width
    @height = height
    @body = nil
    @footer = nil
  end

  attr_reader :page_style, :width, :height

  def new_body(text_style, line_gap)
    allocated_width = @width
    allocated_width -= (@page_style.margin.left + @page_style.margin.right)
    allocated_width -= (@page_style.padding.left + @page_style.padding.right)

    allocated_height = @height
    allocated_height -= (@page_style.margin.top + @page_style.margin.bottom)
    allocated_height -= (@page_style.padding.top + @page_style.padding.bottom)

    @body = TypesetBody.new(self, text_style, line_gap, allocated_width, allocated_height)
  end

  def new_footer(text_style)
    # FIXME: とりあえずの実装
    # フッターはTypesetBodyを流用し、本文領域からto_footer_gapだけ下の位置で、
    # 幅は本文領域と同じとし、マージン、パディング、行送りは0とする
    allocated_width = @width
    allocated_width -= (@page_style.margin.left + @page_style.margin.right)
    allocated_width -= (@page_style.padding.left + @page_style.padding.right)

    allocated_height = @page_style.margin.bottom - @page_style.to_footer_gap

    @footer = TypesetBody.new(self, text_style, 0, allocated_width, allocated_height)
    add_page_number

    @footer
  end

  def break_page
    new_page = @parent.break_page
    new_page.new_footer(@footer.text_style)
    new_page.new_body(@body.text_style, @body.block_style.line_gap) # bodyを返す
  end

  def write_to(content)
    if @body
      left_x = @page_style.margin.left + @page_style.padding.left
      upper_y = @height - @page_style.margin.top - @page_style.padding.top
      @body.write_to content, left_x, upper_y
    end

    if @footer
      left_x = @page_style.margin.left + @page_style.padding.left
      upper_y = @page_style.margin.bottom - @page_style.to_footer_gap
      @footer.write_to content, left_x, upper_y
    end
  end

  private

  # FIXME: スタイルで指定できるようにしたい
  def add_page_number
    page_number = @parent.page_count
    is_odd_page = page_number % 2 == 1
    page_number_str = page_number.to_s

    line = @footer.new_line
    text = line.new_text
    if is_odd_page
      text.add_stretch(1000)  # 右寄せ
      page_number_str.each_char do |char|
        text.add_char(char)
      end
      line.adjust_stretch_width
    else
      page_number_str.each_char do |char|
        text.add_char(char)
      end
    end
  end

end

if __FILE__ == $0
  # not yet
end
