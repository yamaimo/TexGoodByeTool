# 拡張子を判断できるように拡張する

require 'pathname'

module ExtnameExtension

  refine Pathname do

    def is_extname?(extname)
      self_extname = self.extname.downcase
      (self_extname == extname) \
      || (extname.is_a?(Array) && extname.include?(self_extname))
    end

  end

end

if __FILE__ == $0
  using ExtnameExtension

  filename = Pathname.new("hoge.txt")
  puts "filename: #{filename}"

  extname_list = [
    ".txt",
    ".pdf",
    [".txt", ".pdf"], 
    [".pdf", ".tex"], 
  ]
  extname_list.each do |extname|
    puts "#{extname}: #{filename.is_extname?(extname)}"
  end
end
