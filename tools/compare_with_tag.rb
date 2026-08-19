#!/usr/bin/env ruby
# frozen_string_literal: true

# 指定タグの lib と現行作業ツリーの lib で既定経路の全出力を突合する
# リリース前の回帰確認ツール。
#
# 使い方: ruby tools/compare_with_tag.rb <tag>   (例: v2.0.2)
#
# 対象は BMP 全コードポイント(サロゲート除く)の type / type? / 変換系関数
# (対象の一覧は dump_default_outputs.rb の TYPE_FLAGS / CONVERSIONS)。差分の分類規則:
#   - #3 (include?(nil) の修正)起因の type? の変化(新旧とも type が nil で、
#     旧は全フラグ true・新は全フラグ false)だけを許容する
#   - それ以外の差分は 1 件でも回帰として報告し、exit 1 で終える
require "fileutils"
require "tmpdir"

tag = ARGV[0].to_s
abort "usage: ruby tools/compare_with_tag.rb <tag>" if tag.empty?
root = File.expand_path("..", __dir__)
dumper = File.join(__dir__, "dump_default_outputs.rb")

# 指定の lib で dump_default_outputs.rb を別プロセス実行し、出力行を返す。
#
# @param lib_dir [String] `require "moji"` の解決先にする lib ディレクトリ
# @param dumper [String] dump_default_outputs.rb のパス
# @return [Array<String>] ダンプ出力の行の配列
def dump_with(lib_dir, dumper)
  # RUBYLIB / bundler(RUBYOPT) 経由で作業ツリーの lib が -I より優先されると、
  # 旧 lib のつもりの突合が現行実装同士の自己突合に化けるため子プロセスでは無効化する。
  env = { "RUBYLIB" => nil, "RUBYOPT" => nil, "BUNDLE_GEMFILE" => nil }
  out = IO.popen(env, [RbConfig.ruby, "-I", lib_dir, dumper], &:read)
  abort "dump failed for #{lib_dir}" unless $?.success?
  out.lines
end

# rubocop:disable Metrics/BlockLength -- 展開→突合→分類の一続きの手続きで分割の利益がない
Dir.mktmpdir do |dir|
  old_lib = File.join(dir, "lib")
  # タグ側の lib 構成は ls-tree で機械的に列挙する(固定リストだと lib 構成の変更へ
  # 追従し忘れたファイルだけ load path 経由で現行実装へフォールバックし、差分が静かに消える)。
  # タグ名の誤りもここで検出して止める(握りつぶすと自己突合の「回帰なし」に化ける)。
  lib_files = IO.popen(["git", "-C", root, "ls-tree", "-r", "--name-only", tag, "lib"], &:read)
  abort "タグを解決できない: #{tag}" unless $?.success?
  lib_files = lib_files.lines(chomp: true)
  abort "#{tag} に lib/ が無い" if lib_files.empty?

  lib_files.each do |f|
    content = IO.popen(["git", "-C", root, "show", "#{tag}:#{f}"], &:read)
    abort "git show に失敗: #{tag}:#{f}" unless $?.success?

    path = File.join(dir, f)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  old_lines = dump_with(old_lib, dumper)
  new_lines = dump_with(File.join(root, "lib"), dumper)
  abort "行数不一致: old=#{old_lines.size} new=#{new_lines.size}" if old_lines.size != new_lines.size

  allowed = 0
  violations = []
  old_lines.zip(new_lines) do |old_line, new_line|
    next if old_line == new_line

    o = old_line.chomp.split("\t", -1)
    n = new_line.chomp.split("\t", -1)
    # 許容できる差分は #3 の修正が完全に効いた形に限る: type? のビット列のみが
    # 異なり、新旧とも type が nil、旧は全フラグ true(include?(nil) が常に true
    # だったため)、新は全フラグ false。部分的に true が残る形は回帰として扱う。
    same_except_bits = o[0] == n[0] && o[1] == n[1] && o[3..] == n[3..]
    nil_flags_fixed = o[1] == "-" && o[2].delete("1").empty? && n[2].delete("0").empty?
    if same_except_bits && nil_flags_fixed
      allowed += 1
    else
      violations << "U+#{o[0]}: old=#{old_line.chomp.inspect} new=#{new_line.chomp.inspect}"
    end
  end

  puts "対象タグ: #{tag} / 突合行数: #{old_lines.size}"
  puts "許容差分(type? の nil 文字の全フラグ true→false): #{allowed} 行"
  if violations.empty?
    puts "回帰なし(分類規則外の差分 0 件)"
  else
    puts "回帰の疑い #{violations.size} 件:"
    puts violations.first(20)
    exit 1
  end
end
# rubocop:enable Metrics/BlockLength
