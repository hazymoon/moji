# frozen_string_literal: true

# 既定経路(nfc なし・符号化可否 API 不使用)の全出力ダンプ。
# tools/compare_with_tag.rb が新旧の lib に対して別プロセスで実行し、出力を突合する。
# 1 行 = 1 コードポイント(BMP 全域、サロゲート除く)で、列はタブ区切り:
#   cp  type  type?(TYPE_FLAGS 各フラグのビット列)  CONVERSIONS 各関数の結果(コードポイント列 or 例外クラス名)
require "moji"

TYPE_FLAGS = %w[HAN ZEN ALL KANA KANJI HIRA KATA].map { |n| Moji.const_get(n) }.freeze
CONVERSIONS = %i[zen_to_han han_to_zen normalize_zen_han upcase downcase kata_to_hira hira_to_kata].freeze

# 突合対象の lib に無い関数を呼ぶと NoMethodError が「値」として全行に記録され、
# compare_with_tag.rb の violation 表示に本物の回帰が埋もれるため、先に検査して止める
# (定数側は const_get の NameError で即死するので、関数側だけ非対称に静かだった)。
CONVERSIONS.each do |name|
  abort "Moji.#{name} が未定義(この lib とは突合できない)" unless Moji.respond_to?(name)
end

# 変換結果の文字列をコードポイント列の表記へ変換する。
#
# @param value [String] 変換関数の戻り値
# @return [String] 各コードポイントの 16 進表記をカンマで連結した文字列
def dump_value(value)
  value.codepoints.map { |c| format("%04X", c) }.join(",")
end

(0..0xFFFF).each do |cp|
  next if (0xD800..0xDFFF).cover?(cp)

  ch = cp.chr(Encoding::UTF_8)
  type = Moji.type(ch)
  bits = TYPE_FLAGS.map { |tp| Moji.type?(ch, tp) ? "1" : "0" }.join
  conversions = CONVERSIONS.map do |name|
    dump_value(Moji.public_send(name, ch))
  rescue StandardError => e
    e.class.name
  end
  puts(([format("%04X", cp), type ? type.to_s : "-", bits] + conversions).join("\t"))
end
