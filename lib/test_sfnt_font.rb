require_relative 'sfnt_font'

if ARGV.empty?
  puts "[Font file list] ----------"
  puts SfntFont.list
  puts "---------------------------"
  raise "No font file is specified."
end

filename = ARGV[0]
font = SfntFont.load(filename)
puts "path: #{font.path}"
puts "type: #{font.type}"
puts "id  : #{font.id}"
puts "name: #{font.name}"
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
  widths = gids.map{|gid| font.get_width(gid)}
  puts "string: #{str}"
  puts "  cid  : #{cids}"
  puts "  gid  : #{gids}"
  puts "  width: #{widths}"
end
