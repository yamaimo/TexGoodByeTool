# postテーブル

require_relative 'font_data_extension'

class PostTable

  using FontDataExtension

  def self.from_file(file, post_record)
    file.seek(post_record.offset)

    # version(4byte)はスキップ
    file.seek(4, IO::SEEK_CUR)

    italic_angle = file.read_fixed16d16

    # underline_position(2byte),
    # underline_thickness(2byte)はスキップ
    file.seek(4, IO::SEEK_CUR)

    is_fixed_pitch = (file.read_uint32 != 0)

    # min_mem_type42(4byte), max_mem_type42(4byte),
    # min_mem_type1(4byte), max_mem_type1(4byte)は無視

    self.new(italic_angle, is_fixed_pitch)
  end

  def initialize(italic_angle, is_fixed_pitch)
    @italic_angle = italic_angle
    @is_fixed_pitch = is_fixed_pitch
  end

  attr_reader :italic_angle

  def italic?
    @italic_angle != 0
  end

  def fixed_pitch?
    @is_fixed_pitch
  end

end

if __FILE__ == $0
  require_relative 'table_directory'

  if ARGV.empty?
    raise "No font file is specified."
  end

  filename = ARGV[0]

  File.open(filename, 'rb') do |file|
    table_directory = TableDirectory.from_file(file)
    post_table = PostTable.from_file(file, table_directory.records['post'])

    puts "italic angle: #{post_table.italic_angle}"
    puts "italic?     : #{post_table.italic?}"
    puts "fixed pitch?: #{post_table.fixed_pitch?}"
  end
end
