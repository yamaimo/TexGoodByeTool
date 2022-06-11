# Rubyの型で表現したPDFオブジェクトのシリアライズ

module PdfSerializeExtension

  refine TrueClass do

    def serialize
      "true"
    end

  end

  refine FalseClass do

    def serialize
      "false"
    end

  end

  refine NilClass do

    def serialize
      "null"
    end

  end

  refine Numeric do

    def serialize
      self.to_s
    end

  end

  refine Symbol do

    def serialize
      # FIXME: マルチバイト対応
      "/#{self}"
    end

  end

  refine String do

    def serialize
      # FIXME: マルチバイト対応
      "(#{self})"
    end

  end

  refine Array do

    def serialize
      values = self.each.map(&:serialize).join(" ")
      "[#{values}]"
    end

  end

  refine Hash do

    def serialize
      if self.empty?
        "<<>>"
      else
        pairs = self.each.map do |key, value|
          serialized_key = key.to_sym.serialize
          serialized_value = value.serialize
          "#{serialized_key} #{serialized_value}"
        end.join("\n")
        "<<\n#{pairs}\n>>"
      end
    end

  end

end

if __FILE__ == $0
  using PdfSerializeExtension

  data = {
    a: true,
    b: false,
    c: nil,
    d: 1,
    e: 2.0,
    f: :hoge,
    g: "hoge",
    h: [],
    i: [1, 2, 3],
    j: [true, false, nil, 1, 2.0, :hoge, "hoge"],
    k: [[1, 2, 3], [4, [5, 6]]],
    l: {},
    m: {a: "aaa", b: "bbb"},
  }

  puts data.serialize
end
