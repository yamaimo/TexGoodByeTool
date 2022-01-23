require 'rake/clean'
require 'pathname'

# 設定----------------

source = %w(
  README.md
)

output = "README.pdf"

tool = Pathname.pwd

# --------------------

md2pdf = tool / "md2pdf.rb"
lib = tool / "lib"
lib_files = lib.glob("*.rb")

task :default => output

file output => [source, md2pdf, lib_files].flatten do
  ruby md2pdf.to_s, output, *source
end

task :open => output do
  sh "open", output
end

CLEAN.include(output)
