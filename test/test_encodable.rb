# frozen_string_literal: true

require "test_helper"

# Moji.encodable? / Moji.unencodable(v2.1 で追加。#14)のテスト。
# 判定の定義は「Ruby の当該エンコーディングへ String#encode で変換できるか」。
# 代表文字のゴールデンに加え、全コードポイントの replay で範囲表(生成物)と
# 実行環境の Ruby の変換表の一致を機械検証する(テストが特定の Ruby バージョン
# だけで落ちる場合は、Ruby 側の変換表のバージョン差異を意味する)。
class TestEncodable < Minitest::Test
  ENCODINGS = [Encoding::SHIFT_JIS, Encoding::Windows_31J, Encoding.find("EUC-JIS-2004")].freeze

  # 代表文字と [Shift_JIS, Windows-31J, EUC-JIS-2004] での符号化可否。
  # 3 集合が包含関係にないことの固定を兼ねる(髙 は CP932 のみ、𠮟 は X 0213 のみ)。
  GOLDEN = {
    "髙" => [false, true, false], # U+9AD9 IBM 拡張のはしごだか
    "①" => [false, true, true], # U+2460 NEC 特殊文字
    "𠮟" => [false, false, true], # U+20B9F 常用漢字「しかる」(BMP 外)
    "𠮷" => [false, false, false], # U+20BB7 つちよし(CJK 拡張 B、X 0213 外)
    "ｱ" => [true, true, true], # U+FF71 半角カナ(JIS X 0201)
    "逢" => [true, true, true], # 第 1 水準
    "゙" => [false, false, false], # U+3099 結合濁点
    "한" => [false, false, false],
    "A" => [true, true, true],
  }.freeze

  def test_representative_characters_match_golden_table
    GOLDEN.each do |ch, expected|
      ENCODINGS.each_with_index do |enc, i|
        assert_equal(expected[i], Moji.encodable?(ch, enc),
                     format("encodable?(U+%04X, %s)", ch.codepoints.first, enc.name))
      end
    end
  end

  def test_empty_string_is_encodable
    ENCODINGS.each { |enc| assert_equal(true, Moji.encodable?("", enc)) }
  end

  def test_mixed_string_requires_all_characters_encodable
    assert_equal(true, Moji.encodable?("髙橋さん", Encoding::Windows_31J))
    assert_equal(false, Moji.encodable?("髙橋さん", Encoding::Shift_JIS))
  end

  # ---- encoding 引数の受け方 ----

  def test_accepts_encoding_name_string
    assert_equal(false, Moji.encodable?("𠮟", "Windows-31J"))
    assert_equal(true, Moji.encodable?("𠮟", "EUC-JIS-2004"))
  end

  def test_sjis_alias_resolves_to_windows31j
    # Encoding::SJIS は Ruby では Windows-31J の別名。厳密な Shift_JIS とは別物。
    assert_equal(true, Moji.encodable?("髙", Encoding::SJIS))
    assert_same(Moji.unencodable(Encoding::SJIS), Moji.unencodable(Encoding::Windows_31J))
  end

  def test_unsupported_encoding_raises_argument_error
    [Encoding::UTF_8, Encoding::EUC_JP, "US-ASCII"].each do |enc|
      error = assert_raises(ArgumentError) { Moji.encodable?("A", enc) }
      assert_match(/unsupported encoding/, error.message)
    end
    # 存在しないエンコーディング名は Encoding.find の ArgumentError がそのまま出る。
    assert_raises(ArgumentError) { Moji.encodable?("A", "NO-SUCH-ENCODING") }
  end

  def test_nil_resolving_encoding_name_raises_argument_error
    # Encoding.find は "internal" 等の特殊名を受け、default_internal 未設定だと
    # nil を返す。nil 解決でも対応外として ArgumentError になること。
    error = assert_raises(ArgumentError) { Moji.encodable?("A", "internal") }
    assert_match(/unsupported encoding/, error.message)
  end

  # ---- nfc: と非 UTF-8 入力 ----

  def test_nfc_composes_nfd_kana_before_check
    nfd_ga = "ガ" # NFD の「ガ」(カ + 結合濁点)
    assert_equal(false, Moji.encodable?(nfd_ga, Encoding::Windows_31J))
    assert_equal(true, Moji.encodable?(nfd_ga, Encoding::Windows_31J, nfc: true))
  end

  def test_accepts_non_utf8_input
    input = "ガ".encode(Encoding::Windows_31J)
    assert_equal(true, Moji.encodable?(input, Encoding::Windows_31J))
    assert_equal(false, Moji.encodable?("#{input.encode(Encoding::UTF_8)}𠮟", "Windows-31J"))
  end

  # ---- unencodable ----

  def test_unencodable_extracts_offending_characters
    assert_equal(["髙", "①"], "髙橋①".scan(Moji.unencodable(Encoding::Shift_JIS)))
    assert_equal([], "髙橋①".scan(Moji.unencodable(Encoding::Windows_31J)))
  end

  def test_unencodable_is_memoized_per_encoding
    assert_same(Moji.unencodable("Shift_JIS"), Moji.unencodable(Encoding::SHIFT_JIS))
  end

  def test_unencodable_matches_beyond_bmp
    assert_equal(0, Moji.unencodable(Encoding::Windows_31J) =~ "𠮷")
    assert_nil(Moji.unencodable("EUC-JIS-2004") =~ "𠮟")
  end

  # ---- 全数 replay(生成表と実行環境の変換表の一致) ----

  def test_encodable_matches_ruby_encode_for_all_codepoints
    ENCODINGS.each do |enc|
      unenc = Moji.unencodable(enc)
      mismatches = []
      (0..0x10FFFF).each do |cp|
        next if (0xD800..0xDFFF).cover?(cp)

        ch = cp.chr(Encoding::UTF_8)
        expected =
          begin
            ch.encode(enc)
            true
          rescue Encoding::UndefinedConversionError, Encoding::ConverterNotFoundError
            false
          end
        actual = Moji.encodable?(ch, enc)
        regexp_says_unencodable = unenc.match?(ch)
        if actual != expected || regexp_says_unencodable == expected
          mismatches << format("U+%04X expected=%s actual=%s regexp=%s",
                               cp, expected, actual, regexp_says_unencodable)
        end
      end
      assert_empty(mismatches, "#{enc.name}: #{mismatches.first(5).join(', ')}")
    end
  end
end
