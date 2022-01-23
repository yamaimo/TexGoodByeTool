require_relative 'sfnt_font_collection'

if ARGV.empty?
  puts "[Font collection file list] ----------"
  SfntFontCollection.list.each do |filename|
    puts filename
    collections = SfntFontCollection.list_collection(filename)
    collections.each_with_index do |name, i|
      puts "[#{i}] #{name}"
    end
  end
  puts "---------------------------"
  raise "No font collection file is specified."
end

filename = ARGV[0]

if ARGV.size < 2
  puts "[Font collection list] ----------"
  collections = SfntFontCollection.list_collection(filename)
  collections.each_with_index do |name, i|
    puts "[#{i}] #{name}"
  end
  puts "---------------------------"
  raise "No font collection is specified."
end

index = ARGV[1].to_i

font = SfntFontCollection.load(filename, index)
puts "path : #{font.path}"
puts "index: #{font.index}"
puts "type : #{font.type}"
puts "name : #{font.name}"
puts "bound box : #{font.bound_box}"
puts "mode width: #{font.mode_width}"
puts "ascender  : #{font.ascender}"
puts "descender : #{font.descender}"
puts "line gap  : #{font.line_gap}"
puts "weight    : #{font.weight}"
puts "angle     : #{font.italic_angle}"
puts "fixed pitch: #{font.fixed_pitch?}"
puts "bold       : #{font.bold?}"
puts "italic     : #{font.italic?}"
puts "serif      : #{font.serif?}"
puts "script     : #{font.script?}"

["ABCDE", "あいうえお", "斉斎齊齋"].each do |str|
  cids = str.unpack('U*')
  gids = font.convert_to_gid(str)
  widths = gids.map{|gid| font.widths[gid]}
  puts "string: #{str}"
  puts "  cid  : #{cids}"
  puts "  gid  : #{gids}"
  puts "  width: #{widths}"
end
