require 'rake/clean'
require 'pathname'

# 設定ファイル

setting_path = Pathname.pwd / "setting.rb"
raise "'setting.rb' is not found." unless setting_path.exist?

# ライブラリ

md2pdf_path = Pathname.pwd.find do |path|
  if path.basename.to_s == "md2pdf.rb"
    break path
  end
end
tool_files = [__FILE__, setting_path, md2pdf_path]

tool = md2pdf_path.parent
lib = tool / "lib"
lib_files = lib.glob("*.rb")

setting_dsl_path = lib / "setting_dsl.rb"

require md2pdf_path
require setting_dsl_path

# 設定

setting = SettingDsl.read(setting_path.read)

available_target = setting.targets.keys.join("|")
default_target = setting.default_target

# ターゲット

task :default => :build

desc "Build target [target=#{available_target} (default=#{default_target})]"
task :build, [:target] do |task, args|
  target_name = args[:target] || default_target
  Rake::Task[target_name].invoke
end

desc "Open target [target=#{available_target} (default=#{default_target})]"
task :open, [:target] do |task, args|
  target_name = args[:target] || default_target
  Rake::Task[target_name].invoke
  output = setting.targets[target_name].output
  sh "open", output.to_s
end

setting.targets.each do |name, target|
  output = target.output
  sources = target.sources

  task name => output

  file output => (sources + tool_files + lib_files) do
    style = setting.styles[target.style]
    md2pdf output, sources, style, setting.fonts
  end

  CLEAN.include(output)
end
