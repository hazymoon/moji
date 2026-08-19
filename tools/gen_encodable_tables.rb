#!/usr/bin/env ruby
# frozen_string_literal: true

# lib/moji/encodable_ranges.rb(Moji.encodable? / Moji.unencodable 用の範囲表)を
# 生成する。Ruby の String#encode 可否を U+0000〜U+10FFFF(サロゲート除く)の
# 全コードポイントで replay し、符号化可能なコードポイントを連続範囲へ畳む。
# 手書きの転記はせず、Ruby の変換表そのものを定義元とする。
#
# 使い方(生成は CI マトリクス最小の Ruby 3.3 で行う):
#   mise x ruby@3.3 -- ruby tools/gen_encodable_tables.rb
#
# 生成表と実行環境の変換表の一致は test/test_encodable.rb の全数 replay
# テストが CI の全 Ruby バージョンで機械検証する(表は生成時バージョンで
# 固定されるため、テストが特定バージョンだけ落ちる場合は Ruby 側の
# 変換表のバージョン差異を意味する)。
#
# EUC-JIS-2004 集合は x0213.org の公開マッピング表(euc-jis-2004-std.txt)とも
# 突合済みで、差分は「C1 制御の扱い」「¥/‾ の std/Windows 系統選択」
# 「encode 側別名」に限られる(詳細は GitHub issue #14 のコメント)。
# 本 gem は Ruby の変換表を定義元とする。

ENCODING_NAMES = %w[Shift_JIS Windows-31J EUC-JIS-2004].freeze
SURROGATE_RANGE = (0xD800..0xDFFF)
MAX_CODEPOINT = 0x10FFFF

def encodable_ranges(enc)
  ranges = []
  current = nil
  (0..MAX_CODEPOINT).each do |cp|
    next if SURROGATE_RANGE.cover?(cp)

    ok =
      begin
        cp.chr(Encoding::UTF_8).encode(enc)
        true
      rescue Encoding::UndefinedConversionError, Encoding::ConverterNotFoundError
        false
      end
    if ok
      if current && current[1] == cp - 1
        current[1] = cp
      else
        current = [cp, cp]
        ranges << current
      end
    end
  end
  ranges
end

out = <<~HEADER
  # frozen_string_literal: true

  # 本ファイルは tools/gen_encodable_tables.rb による生成物。手で編集しないこと。
  # 生成コマンド: mise x ruby@3.3 -- ruby tools/gen_encodable_tables.rb
  # 生成時 Ruby: #{RUBY_VERSION}
  module Moji
    module Detail
      # Ruby の String#encode 可否を U+0000〜U+10FFFF(サロゲート除く)で
      # replay した「符号化可能コードポイント」の連続範囲 [先頭, 末尾]。
      # キーはエンコーディング名。Moji.encodable? / Moji.unencodable が参照する。
      ENCODABLE_RANGE_DATA = {
HEADER

ENCODING_NAMES.each do |name|
  enc = Encoding.find(name)
  ranges = encodable_ranges(enc)
  total = ranges.sum { |f, l| l - f + 1 }
  out << "      # #{name}: #{total} コードポイント / #{ranges.size} 範囲\n"
  out << "      \"#{name}\" => [\n"
  ranges.each_slice(4) do |slice|
    row = slice.map { |f, l| format("[0x%04X, 0x%04X]", f, l) }.join(", ")
    out << "        #{row},\n"
  end
  out << "      ].freeze,\n"
end

out << <<~FOOTER
      }.freeze
    end
  end
FOOTER

path = File.expand_path("../lib/moji/encodable_ranges.rb", __dir__)
File.write(path, out)
puts "generated: #{path} (#{out.bytesize} bytes, Ruby #{RUBY_VERSION})"
