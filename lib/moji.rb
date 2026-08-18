# frozen_string_literal: true

# このファイルの文字コードは UTF-8 です。
# 「ａ-ｚ」等の Unicode 文字をリテラルに含むため、エンコーディングを変換するツールを通してはいけません。

require "moji/detail"
require "moji/flag_set_maker"
require "moji/version"

# 日本語の文字種判定、文字種変換(半角→全角、ひらがな→カタカナなど)を行うモジュール。
#
# 文字種は {FlagSetMaker::Flags} のビットフラグ定数で表し、`|` で合成して
# 複数文字種を同時に指定できる。定数の一覧と意味は README.md を参照。
#
# どのエンコーディングの文字列を渡しても動作するが、String#encoding が正しく
# 設定されている必要がある。正規表現を返す関数は Encoding.default_internal
# (未設定の場合は UTF-8)用の正規表現を返す。
#
# @example 文字種判定
#   Moji.type("漢")             # => Moji::ZEN_KANJI
#   Moji.type?("Ａ", Moji::ZEN) # => true
# @example 文字種変換
#   Moji.zen_to_han("Ｒｕｂｙ") # => "Ruby"
#   Moji.kata_to_hira("ルビー") # => "るびー"
# @example 文字種による正規表現
#   /#{Moji.kata}+#{Moji.hira}+/ =~ "ぼくドラえもん" # => 2
module Moji
  extend(FlagSetMaker)

  # コードポイント範囲の組から 1 文字にマッチする正規表現を作る。
  #
  # @param args [Array<Integer>] 範囲の先頭・末尾コードポイントの繰り返し
  # @return [Regexp] `\uXXXX-\uXXXX` 形式の文字クラス
  # @api private
  def self.uni_range(*args)
    str = args.each_slice(2).map { |f, e| format('\u%04x-\u%04x', f, e) }.join
    /[#{str}]/
  end

  make_flag_set(%i[
                  HAN_CONTROL HAN_ASYMBOL HAN_JSYMBOL HAN_NUMBER HAN_UPPER HAN_LOWER HAN_KATA
                  ZEN_ASYMBOL ZEN_JSYMBOL ZEN_NUMBER ZEN_UPPER ZEN_LOWER ZEN_HIRA ZEN_KATA
                  ZEN_GREEK ZEN_CYRILLIC ZEN_LINE ZEN_KANJI
                ])

  # ---- 基本文字種の組み合わせと別名(各定数の意味は README.md の一覧を参照) ----
  HAN_SYMBOL = HAN_ASYMBOL | HAN_JSYMBOL
  HAN_ALPHA = HAN_UPPER | HAN_LOWER
  HAN_ALNUM = HAN_ALPHA | HAN_NUMBER
  HAN = HAN_CONTROL | HAN_SYMBOL | HAN_ALNUM | HAN_KATA
  ZEN_SYMBOL = ZEN_ASYMBOL | ZEN_JSYMBOL
  ZEN_ALPHA = ZEN_UPPER | ZEN_LOWER
  ZEN_ALNUM = ZEN_ALPHA | ZEN_NUMBER
  ZEN_KANA = ZEN_KATA | ZEN_HIRA
  ZEN = ZEN_SYMBOL | ZEN_ALNUM | ZEN_KANA | ZEN_GREEK | ZEN_CYRILLIC | ZEN_LINE | ZEN_KANJI
  ASYMBOL = HAN_ASYMBOL | ZEN_ASYMBOL
  JSYMBOL = HAN_JSYMBOL | ZEN_JSYMBOL
  SYMBOL = HAN_SYMBOL | ZEN_SYMBOL
  NUMBER = HAN_NUMBER | ZEN_NUMBER
  UPPER = HAN_UPPER | ZEN_UPPER
  LOWER = HAN_LOWER | ZEN_LOWER
  ALPHA = HAN_ALPHA | ZEN_ALPHA
  ALNUM = HAN_ALNUM | ZEN_ALNUM
  HIRA = ZEN_HIRA
  KATA = HAN_KATA | ZEN_KATA
  KANA = KATA | ZEN_HIRA
  GREEK = ZEN_GREEK
  CYRILLIC = ZEN_CYRILLIC
  LINE = ZEN_LINE
  KANJI = ZEN_KANJI
  ALL = HAN | ZEN

  # 基本文字種 → その 1 文字にマッチする正規表現。
  # {Moji.type} は挿入順に走査して最初にマッチした文字種を返すため、
  # エントリの順序に意味がある(例: 仝 は ZEN_KANJI の範囲だが ZEN_JSYMBOL が先に取る)。
  # 本家 1.6 ではこの Hash は可変で、利用者が判定範囲を差し替える余地があった。
  # bug-for-bug 互換のため freeze しない。
  CHAR_REGEXPS = { # rubocop:disable Style/MutableConstant
    HAN_CONTROL => /[\x00-\x1f\x7f]/,
    HAN_ASYMBOL =>
      Regexp.new("[#{Detail::HAN_ASYMBOL_LIST.gsub(/[\[\]\-\^\\]/) { "\\#{$&}" }}]"),
    HAN_JSYMBOL => Regexp.new("[#{Detail::HAN_JSYMBOL1_LIST}]"),
    HAN_NUMBER => /[0-9]/,
    HAN_UPPER => /[A-Z]/,
    HAN_LOWER => /[a-z]/,
    HAN_KATA => /[ｦ-ｯｱ-ﾝ]/,
    ZEN_ASYMBOL => Regexp.new("[#{Detail::ZEN_ASYMBOL_LIST}]"),
    ZEN_JSYMBOL => Regexp.new("[#{Detail::ZEN_JSYMBOL_LIST}]"),
    ZEN_NUMBER => /[０-９]/,
    ZEN_UPPER => /[Ａ-Ｚ]/,
    ZEN_LOWER => /[ａ-ｚ]/,
    ZEN_HIRA => /[ぁ-ん]/,
    ZEN_KATA => /[ァ-ヶ]/,
    ZEN_GREEK => /[Α-Ωα-ω]/,
    ZEN_CYRILLIC => /[А-Яа-я]/,
    ZEN_LINE => uni_range(0x2570, 0x25ff),
    ZEN_KANJI => uni_range(0x3400, 0x4dbf, 0x4e00, 0x9fff, 0xf900, 0xfaff),
  }

  # 文字 ch の文字種を返す。
  #
  # 複数文字の文字列を渡した場合は先頭 1 文字で判定する。
  #
  # @param ch [String] 判定する文字
  # @return [FlagSetMaker::Flags, nil] 基本文字種の定数。どの分類にも
  #   当てはまらない文字(ハングル、BMP 外の文字など)は nil
  # @example
  #   Moji.type("漢") # => Moji::ZEN_KANJI
  def type(ch)
    Detail.convert_encoding(ch) do |c|
      c = c.slice(/\A./m)
      result = nil
      CHAR_REGEXPS.each do |tp, reg|
        if c =~ reg
          result = tp
          break
        end
      end
      result
    end
  end

  # 文字 ch が文字種 tp に含まれるかを返す。
  #
  # @param ch [String] 判定する文字
  # @param tp [FlagSetMaker::Flags] 文字種(定数と、それらの `|` 合成)
  # @return [Boolean]
  # @example
  #   Moji.type?("Ａ", Moji::ZEN) # => true
  def type?(ch, tp)
    Detail.convert_encoding(ch) do |c|
      tp.include?(type(c))
    end
  end

  # 文字種 tp の 1 文字を表す正規表現を返す。
  #
  # @param tp [FlagSetMaker::Flags] 文字種(定数と、それらの `|` 合成)
  # @param encoding [Encoding, nil] 返す正規表現のエンコーディング。省略時は
  #   Encoding.default_internal(未設定なら UTF-8)
  # @return [Regexp]
  # @example
  #   Moji.regexp(Moji::HIRA) # => /[ぁ-ん]/
  def regexp(tp, encoding = nil)
    regs = CHAR_REGEXPS.filter_map { |tp2, reg| reg if tp.include?(tp2) }
    reg = regs.size == 1 ? regs[0] : Regexp.new(regs.join("|"))

    encoding ||= Encoding.default_internal || Encoding::UTF_8
    if encoding == Encoding::UTF_8
      reg
    else
      Regexp.new(reg.to_s.encode(encoding))
    end
  end

  # 文字列 str の全角を半角に変換して返す。
  #
  # @param str [String] 変換する文字列
  # @param tp [FlagSetMaker::Flags] 変換対象とする文字種
  # @return [String] 変換結果(エンコーディングは入力と同じ)
  # @example
  #   Moji.zen_to_han("Ｒｕｂｙ！？")                # => "Ruby!?"
  #   Moji.zen_to_han("Ｒｕｂｙ！？", Moji::ALPHA)   # => "Ruby！？"
  def zen_to_han(str, tp = ALL)
    Detail.convert_encoding(str) do |s|
      if tp.include?(ZEN_KATA)
        reg = Regexp.new(format("[%s]", Detail::ZEN_KATA_LISTS.join))
        s = s.gsub(reg) do
          Detail::ZEN_KATA_LISTS.each_with_index do |list, i|
            pos = list.index($&)
            break Detail::HAN_KATA_LIST[pos] + Detail::HAN_VSYMBOLS[i] if pos
          end
        end
      end
      s = s.tr("ａ-ｚ", "a-z") if tp.include?(ZEN_LOWER)
      s = s.tr("Ａ-Ｚ", "A-Z") if tp.include?(ZEN_UPPER)
      s = s.tr("０-９", "0-9") if tp.include?(ZEN_NUMBER)
      s = s.tr(Detail::ZEN_ASYMBOL_LIST, Detail::HAN_ASYMBOL_TR_LIST) if tp.include?(ZEN_ASYMBOL)
      s = s.tr(Detail::ZEN_JSYMBOL1_LIST, Detail::HAN_JSYMBOL1_LIST) if tp.include?(ZEN_JSYMBOL)
      s
    end
  end

  # 文字列 str の半角を全角に変換して返す。
  #
  # @param str [String] 変換する文字列
  # @param tp [FlagSetMaker::Flags] 変換対象とする文字種
  # @return [String] 変換結果(エンコーディングは入力と同じ)
  # @example
  #   Moji.han_to_zen("Ruby!?")                 # => "Ｒｕｂｙ！？"
  #   Moji.han_to_zen("Ruby!?", Moji::SYMBOL)   # => "Ruby！？"
  def han_to_zen(str, tp = ALL)
    Detail.convert_encoding(str) do |s|
      # [半]濁音記号がJSYMBOLに含まれるので、KATAの変換をJSYMBOLより前にやる必要あり。
      if tp.include?(HAN_KATA)
        s = s.gsub(/(#{han_kata})([ﾞﾟ]?)/) do
          i = { "" => 0, "ﾞ" => 1, "ﾟ" => 2 }[$2]
          pos = Detail::HAN_KATA_LIST.index($1)
          zen = Detail::ZEN_KATA_LISTS[i][pos]
          !zen || zen == "" ? Detail::ZEN_KATA_LISTS[0][pos] + $2 : zen
        end
      end
      s = s.tr("a-z", "ａ-ｚ") if tp.include?(HAN_LOWER)
      s = s.tr("A-Z", "Ａ-Ｚ") if tp.include?(HAN_UPPER)
      s = s.tr("0-9", "０-９") if tp.include?(HAN_NUMBER)
      s = s.tr(Detail::HAN_ASYMBOL_TR_LIST, Detail::ZEN_ASYMBOL_LIST) if tp.include?(HAN_ASYMBOL)
      s = s.tr(Detail::HAN_JSYMBOL1_LIST, Detail::ZEN_JSYMBOL1_LIST) if tp.include?(HAN_JSYMBOL)
      s
    end
  end

  # 文字列 str の全角、半角を一般的なものに統一する。
  #
  # ASCII に含まれる記号と英数字(ALNUM|ASYMBOL)を半角に、
  # それ以外の記号とカタカナ(JSYMBOL|HAN_KATA)を全角に変換する。
  #
  # @param str [String] 変換する文字列
  # @return [String] 変換結果(エンコーディングは入力と同じ)
  def normalize_zen_han(str)
    Detail.convert_encoding(str) do |s|
      zen_to_han(han_to_zen(s, HAN_JSYMBOL | HAN_KATA), ZEN_ALNUM | ZEN_ASYMBOL)
    end
  end

  # 文字列 str の小文字を大文字に変換して返す。
  #
  # ギリシャ文字、キリル文字には対応していない。
  #
  # @param str [String] 変換する文字列
  # @param tp [FlagSetMaker::Flags] 変換対象とする文字種
  # @return [String] 変換結果(エンコーディングは入力と同じ)
  # @example
  #   Moji.upcase("Ｒｕｂｙ") # => "ＲＵＢＹ"
  def upcase(str, tp = LOWER)
    Detail.convert_encoding(str) do |s|
      s = s.tr("a-z", "A-Z") if tp.include?(HAN_LOWER)
      s = s.tr("ａ-ｚ", "Ａ-Ｚ") if tp.include?(ZEN_LOWER)
      s
    end
  end

  # 文字列 str の大文字を小文字に変換して返す。
  #
  # ギリシャ文字、キリル文字には対応していない。
  #
  # @param str [String] 変換する文字列
  # @param tp [FlagSetMaker::Flags] 変換対象とする文字種
  # @return [String] 変換結果(エンコーディングは入力と同じ)
  # @example
  #   Moji.downcase("Ｒｕｂｙ") # => "ｒｕｂｙ"
  def downcase(str, tp = UPPER)
    Detail.convert_encoding(str) do |s|
      s = s.tr("A-Z", "a-z") if tp.include?(HAN_UPPER)
      s = s.tr("Ａ-Ｚ", "ａ-ｚ") if tp.include?(ZEN_UPPER)
      s
    end
  end

  # 文字列 str の全角カタカナをひらがなに変換して返す。
  #
  # 半角カタカナは直接変換できない。{han_to_zen} で全角にしてから変換すること。
  #
  # @param str [String] 変換する文字列
  # @return [String] 変換結果(エンコーディングは入力と同じ)
  # @example
  #   Moji.kata_to_hira("ルビー") # => "るびー"
  def kata_to_hira(str)
    Detail.convert_encoding(str) do |s|
      s.tr("ァ-ン", "ぁ-ん")
    end
  end

  # 文字列 str のひらがなを全角カタカナに変換して返す。
  #
  # @param str [String] 変換する文字列
  # @return [String] 変換結果(エンコーディングは入力と同じ)
  # @example
  #   Moji.hira_to_kata("るびー") # => "ルビー"
  def hira_to_kata(str)
    Detail.convert_encoding(str) do |s|
      s.tr("ぁ-ん", "ァ-ン")
    end
  end

  module_function(
    :type, :type?, :regexp, :zen_to_han, :han_to_zen, :normalize_zen_han, :upcase, :downcase,
    :kata_to_hira, :hira_to_kata
  )

  # 文字種定数に対応する正規表現メソッドを定義する。
  #
  # @param name [Symbol] メソッド名
  # @param tp [FlagSetMaker::Flags] 対応する文字種
  # @api private
  def self.define_regexp_method(name, tp)
    define_method(name) do |*args|
      regexp(tp, *args)
    end
    module_function(name)
  end

  # han_control, han_asymbol, …など、文字種定数に対応するモジュール関数を定義。
  # 各メソッドはその文字種の 1 文字を表す正規表現を返す(Moji.kana は
  # Moji.regexp(Moji::KANA) と同じ)。文字種定数を追加すれば対応メソッドも自動で生える。
  constants.each do |cons|
    val = const_get(cons)
    define_regexp_method(cons.downcase, val) if val.is_a?(FlagSetMaker::Flags)
  end
end
