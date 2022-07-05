# マクロ処理
#
# オリジナルは以下 (MIT License):
# https://github.com/jeremyevans/erubi/blob/master/lib/erubi.rb

class MacroProcessor

  class TemplateCompiler

    EXPR_STAG = "{{"
    EXPR_ETAG = "}}"

    CODE_STAG = "{%"
    CODE_ETAG = "%}"

    COMM_STAG = "{#"
    COMM_ETAG = "#}"

    REGEXP = /({{|{%|{#)(.*?)(}}|%}|#})([ \t]*\r?\n)?/m
    # 上記だとエスケープ処理が厄介。
    # /(開始のエスケープ)|(開始〜終了)/
    # みたいにして、開始のエスケープのときにはそれだけ出してやるとよさそう。
    # 開始さえされなければ終了が単体でいるのはエスケープ不要になるので。
    # memo: /xxx#{exp}yyy/oとすれば、一度だけexpが式展開される

    BUFVAR = "_buf"

    def initialize(template)
      @template = template
      @src = nil
    end

    def compile
      @src || begin
        @src = String.new
        add_preamble()

        pos = 0
        is_bol = true   # bol = beginning of line
        @template.scan(REGEXP) do |stag, code, etag, rspace|
          match = Regexp.last_match
          len = match.begin(0) - pos
          text = @template[pos, len]

          case stag
          when EXPR_STAG
            handle_expression(text, code, rspace)
          when CODE_STAG
            handle_code(is_bol, text, code, rspace)
          when COMM_STAG
            handle_comment(is_bol, text, code, rspace)
          else
            # ここには来ないはず
            raise "Invalid start tag: #{stag}"
          end

          pos = match.end(0)
          is_bol = rspace
        end

        # 最後のマッチ以降のテキストを処理する
        rest = @template[pos..-1]
        add_text(rest)

        add_postamble()
        @src.freeze
      end
    end

    private

    def add_preamble
      @src << "begin; __original_outvar = #{BUFVAR} if defined?(#{BUFVAR}); "
      @src << "#{BUFVAR} = String.new; "
    end

    def add_postamble
      @src << "\n" if @src[-1] != "\n"
      @src << "#{BUFVAR}.to_s\n"
      @src << "; ensure\n  " << BUFVAR << " = __original_outvar\nend\n"
    end

    def handle_expression(text, code, rspace)
      add_text(text)
      add_expression(code)
      add_text(rspace) if rspace
    end

    def handle_code(is_bol, text, code, rspace)
      text, lspace = split_text_lspace(is_bol, text)
      add_text(text)
      if lspace && rspace
        add_code("#{lspace}#{code}#{rspace}")
      else
        add_text(lspace) if lspace
        add_code(code)
        add_text(rspace) if rspace
      end
    end

    def handle_comment(is_bol, text, code, rspace)
      text, lspace = split_text_lspace(is_bol, text)
      add_text(text)
      n = code.count("\n") + (rspace ? 1 : 0)
      if lspace && rspace
        add_code("\n" * n)
      else
        add_text(lspace) if lspace
        add_code("\n" * n)
        add_text(rspace) if rspace
      end
    end

    def split_text_lspace(is_bol, text)
      # textが空の場合、直前でもヒットしていて、
      # is_bolがtrueなら行の先頭にいるのでlspaceは""、
      # そうでなければ行の途中にいるのでlspaceはnil
      if text.empty?
        lspace = is_bol ? "" : nil
        return text, lspace
      end

      # textが空でなく最後が改行の場合、
      # 行の先頭でマッチしてるのでlspaceは""
      if text[-1] == "\n"
        return text, ""
      end

      rindex = text.rindex("\n")

      # textの途中に改行が含まれてる場合、
      # 改行以降がすべて空白文字なら、それをlspaceとして分離する
      if rindex
        before_lf = text[0..rindex]
        after_lf = text[(rindex+1)..-1]
        if /\A[ \t]*\z/.match?(after_lf)
          return before_lf, after_lf
        else
          return text, nil
        end
      end

      # textに改行が含まれてない場合、
      # 行頭からすべて空白文字なら、それをlspaceとする
      if is_bol && /\A[ \t]*\z/.match?(text)
        return '', text
      else
        return text, nil
      end
    end

    def add_text(text)
      return if text.empty?

      # "xxx'yyy"は"xxx\\\\'yyy"に置き換えられる
      # これがソースに出力されるとき"'xxx\\'yyy'"になる
      # これをevalすると'xxx\'yyy'が評価され、"xxx'yyy"となる
      # 同様に、"xxx\yyy"は"xxx\\\\\yyy"に置き換える
      if text.frozen?
        text = text.gsub(/['\\]/, '\\\\\&')
      else
        text.gsub!(/['\\]/, '\\\\\&')
      end

      concat_text_code = " #{BUFVAR} << '#{text}'.freeze;"
      @src << concat_text_code
    end

    def add_code(code)
      @src << code
      @src << ';' if code[-1] != "\n"
    end

    def add_expression(code)
      concat_expression_code = " #{BUFVAR} << (#{code}).to_s;"
      @src << concat_expression_code
    end

  end

  class ContextProvider
    def macro_context
      binding
    end
  end

  def initialize(macro="")
    @macro = macro
    @context_provider = ContextProvider.new
  end

  def process(template)
    macro_context = @context_provider.macro_context
    eval(@macro, macro_context, "(macro)", 1)

    compiler = TemplateCompiler.new(template)
    src = compiler.compile
    eval(src, macro_context, "(template)", 1)
  end

end

if __FILE__ == $0
  macro = <<~END_OF_MACRO
    name = "hoge"

    def factorial(n)
      (n > 0) ? n * factorial(n-1) : 1
    end

    def div_zero(i)
      i / 0
    end
  END_OF_MACRO

  template = <<~END_OF_TEMPLATE
    Hello {{ name }}.

    "'"と"\\"のエスケープはOK?

    {% 5.times do |i| %}
    - {{ i }} * {{ i }} = {{ i * i }}
    {% end %}

    {% 5.times do |i| %}
    - factorial({{ i }}) = {{ factorial(i) }}
    {% end %}

    Bye {{ name }}.
  END_OF_TEMPLATE

  processor = MacroProcessor.new(macro)
  puts processor.process(template)
end
