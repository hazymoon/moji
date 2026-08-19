# frozen_string_literal: true

require "test_helper"

# Moji.type / Moji.type? のゴールデンテスト。
# 期待値は現行リリースの意図した挙動を固定したもの。v2.0 系までは本家 1.6 の
# 実測値（バグ込み）を固定していたが、v2.1 で type? の nil 素通し（#3）を
# 修正した。それ以外の直感に反する挙動（罫線の範囲ずれなど）は本家互換のまま
# 意図的に固定している。
class TestType < Minitest::Test
  # 対応表の正データは test_helper の GoldenFixtures に集約している
  # （lib の Detail は private 実装なので参照しない）。
  include GoldenFixtures

  def assert_type(expected, ch, message = nil)
    message ||= format("U+%s (%s)", ch.codepoints.map { |c| format("%04X", c) }.join(","), ch)
    assert_equal(expected, Moji.type(ch), message)
  end

  def assert_type_nil(ch, message = nil)
    message ||= format("U+%s (%s)", ch.codepoints.map { |c| format("%04X", c) }.join(","), ch)
    assert_nil(Moji.type(ch), message)
  end

  # ---------------------------------------------------------------------------
  # 18 個の基本文字種: 代表文字と CHAR_REGEXPS の範囲境界
  # ---------------------------------------------------------------------------

  def test_type_han_control
    assert_type(Moji::HAN_CONTROL, "\u0000") # 範囲 \x00-\x1f の先頭
    assert_type(Moji::HAN_CONTROL, "\u001F") # 範囲 \x00-\x1f の末尾
    assert_type(Moji::HAN_CONTROL, "\u007F") # DEL
    assert_type(Moji::HAN_CONTROL, "\t")
    assert_type(Moji::HAN_CONTROL, "\r")
    assert_type(Moji::HAN_CONTROL, "\e")
  end

  # Ver.1.4 で「Moji.type("\n") が nil を返す」バグが修正された既知ケース。
  def test_type_newline_is_han_control
    assert_type(Moji::HAN_CONTROL, "\n")
  end

  def test_type_han_asymbol_boundaries
    assert_type(Moji::HAN_ASYMBOL, " ")  # リスト先頭 U+0020
    assert_type(Moji::HAN_ASYMBOL, "~")  # リスト末尾 U+007E
    assert_type(Moji::HAN_ASYMBOL, "!")
    assert_type(Moji::HAN_ASYMBOL, "\\") # 正規表現内でエスケープされる文字
    assert_type(Moji::HAN_ASYMBOL, "^")
    assert_type(Moji::HAN_ASYMBOL, "-")
    assert_type(Moji::HAN_ASYMBOL, "[")
    assert_type(Moji::HAN_ASYMBOL, "]")
  end

  def test_type_han_jsymbol_boundaries
    assert_type(Moji::HAN_JSYMBOL, "｡") # U+FF61
    assert_type(Moji::HAN_JSYMBOL, "･") # U+FF65 Ver.1.3 で判別できるようになった半角中黒
    assert_type(Moji::HAN_JSYMBOL, "ｰ") # U+FF70 半角カタカナ範囲の隙間
    assert_type(Moji::HAN_JSYMBOL, "ﾞ") # U+FF9E
    assert_type(Moji::HAN_JSYMBOL, "ﾟ") # U+FF9F
  end

  def test_type_han_number_boundaries
    assert_type(Moji::HAN_NUMBER, "0")
    assert_type(Moji::HAN_NUMBER, "9")
    assert_type(Moji::HAN_NUMBER, "5")
  end

  def test_type_han_upper_boundaries
    assert_type(Moji::HAN_UPPER, "A")
    assert_type(Moji::HAN_UPPER, "Z")
  end

  def test_type_han_lower_boundaries
    assert_type(Moji::HAN_LOWER, "a")
    assert_type(Moji::HAN_LOWER, "z")
  end

  # HAN_KATA は /[ｦ-ｯｱ-ﾝ]/ の 2 レンジ。間の U+FF70(ｰ) は HAN_JSYMBOL に落ちる。
  def test_type_han_kata_boundaries
    assert_type(Moji::HAN_KATA, "ｦ") # U+FF66 第1レンジ先頭
    assert_type(Moji::HAN_KATA, "ｯ") # U+FF6F 第1レンジ末尾
    assert_type(Moji::HAN_KATA, "ｱ") # U+FF71 第2レンジ先頭
    assert_type(Moji::HAN_KATA, "ﾝ") # U+FF9D 第2レンジ末尾
    assert_type(Moji::HAN_JSYMBOL, "･") # U+FF65 第1レンジの直前
    assert_type(Moji::HAN_JSYMBOL, "ｰ") # U+FF70 レンジの間
    assert_type(Moji::HAN_JSYMBOL, "ﾞ") # U+FF9E 第2レンジの直後
  end

  def test_type_zen_asymbol_boundaries
    assert_type(Moji::ZEN_ASYMBOL, "　") # U+3000 リスト先頭
    assert_type(Moji::ZEN_ASYMBOL, "￣") # U+FFE3 リスト末尾
    assert_type(Moji::ZEN_ASYMBOL, "！")
    assert_type(Moji::ZEN_ASYMBOL, "￥") # U+FFE5 バックスラッシュ相当
    assert_type(Moji::ZEN_ASYMBOL, "”") # U+201D
    assert_type(Moji::ZEN_ASYMBOL, "‘") # U+2018
    assert_type(Moji::ZEN_ASYMBOL, "’") # U+2019
  end

  def test_type_zen_jsymbol_boundaries
    assert_type(Moji::ZEN_JSYMBOL, "、") # リスト先頭 U+3001
    assert_type(Moji::ZEN_JSYMBOL, "〓") # リスト末尾 U+3013
    assert_type(Moji::ZEN_JSYMBOL, "ー") # U+30FC 長音記号はカタカナ扱いしない
    assert_type(Moji::ZEN_JSYMBOL, "ヽ") # U+30FD
    assert_type(Moji::ZEN_JSYMBOL, "ヾ") # U+30FE
    assert_type(Moji::ZEN_JSYMBOL, "・") # U+30FB
    assert_type(Moji::ZEN_JSYMBOL, "〜") # U+301C 波ダッシュ
    assert_type(Moji::ZEN_JSYMBOL, "～") # U+FF5E 全角チルダ
  end

  def test_type_zen_number_boundaries
    assert_type(Moji::ZEN_NUMBER, "０") # U+FF10
    assert_type(Moji::ZEN_NUMBER, "９") # U+FF19
    assert_type(Moji::ZEN_ASYMBOL, "／") # U+FF0F 直前
    assert_type(Moji::ZEN_ASYMBOL, "：") # U+FF1A 直後
  end

  def test_type_zen_upper_boundaries
    assert_type(Moji::ZEN_UPPER, "Ａ") # U+FF21
    assert_type(Moji::ZEN_UPPER, "Ｚ") # U+FF3A
    assert_type(Moji::ZEN_ASYMBOL, "＠") # U+FF20 直前
    assert_type(Moji::ZEN_ASYMBOL, "［") # U+FF3B 直後
  end

  def test_type_zen_lower_boundaries
    assert_type(Moji::ZEN_LOWER, "ａ") # U+FF41
    assert_type(Moji::ZEN_LOWER, "ｚ") # U+FF5A
    assert_type(Moji::ZEN_JSYMBOL, "｀") # U+FF40 直前
    assert_type(Moji::ZEN_ASYMBOL, "｛") # U+FF5B 直後
  end

  # ZEN_HIRA は /[ぁ-ん]/ (U+3041-U+3093)。ゔ U+3094 以降は範囲外で nil。
  def test_type_zen_hira_boundaries
    assert_type(Moji::ZEN_HIRA, "ぁ") # U+3041
    assert_type(Moji::ZEN_HIRA, "ん") # U+3093
    assert_type(Moji::ZEN_HIRA, "が") # が（合成済み濁音）は 1 コードポイント
    assert_type_nil("\u3040") # U+3040 未割り当て、範囲の直前
    assert_type_nil("ゔ") # U+3094 ひらがなだが範囲外
    assert_type_nil("\u3095") # U+3095 小書きか、範囲外
    assert_type_nil("ゟ") # U+309F より
  end

  # ZEN_KATA は /[ァ-ヶ]/ (U+30A1-U+30F6)。ヷ U+30F7 以降は範囲外で nil。
  def test_type_zen_kata_boundaries
    assert_type(Moji::ZEN_KATA, "ァ") # U+30A1
    assert_type(Moji::ZEN_KATA, "ヶ") # U+30F6
    assert_type(Moji::ZEN_KATA, "ヴ") # U+30F4
    assert_type_nil("\u30A0") # U+30A0 カタカナ用二重ハイフン、範囲の直前
    assert_type_nil("ヷ")             # U+30F7
    assert_type_nil("ヺ")             # U+30FA
  end

  # ZEN_GREEK は /[Α-Ωα-ω]/。未割り当ての U+03A2 も範囲に入るため GREEK になる。
  def test_type_zen_greek_boundaries
    assert_type(Moji::ZEN_GREEK, "Α") # U+0391
    assert_type(Moji::ZEN_GREEK, "Ω") # U+03A9
    assert_type(Moji::ZEN_GREEK, "α") # U+03B1
    assert_type(Moji::ZEN_GREEK, "ω") # U+03C9
    assert_type(Moji::ZEN_GREEK, "΢") # U+03A2 未割り当てだが範囲内なので GREEK
    assert_type_nil("ΐ") # U+0390 範囲の直前
    assert_type_nil("Ϊ") # U+03AA 大文字レンジの直後
    assert_type_nil("ΰ") # U+03B0 小文字レンジの直前
    assert_type_nil("ϊ") # U+03CA 小文字レンジの直後
  end

  # ZEN_CYRILLIC は /[А-Яа-я]/。Ё U+0401 / ё U+0451 は範囲外なので nil。
  def test_type_zen_cyrillic_boundaries
    assert_type(Moji::ZEN_CYRILLIC, "А") # U+0410
    assert_type(Moji::ZEN_CYRILLIC, "Я") # U+042F
    assert_type(Moji::ZEN_CYRILLIC, "а") # U+0430
    assert_type(Moji::ZEN_CYRILLIC, "я") # U+044F
    assert_type_nil("Ё") # U+0401 キリル文字だが範囲外
    assert_type_nil("ё") # U+0451 キリル文字だが範囲外
    assert_type_nil("Џ") # U+040F 範囲の直前
    assert_type_nil("ѐ") # U+0450 範囲の直後
  end

  # ZEN_LINE の範囲は U+2570-U+25FF。Box Drawing の大半（U+2500-U+256F）は含まれず、
  # ドキュメントの「罫線のかけら」という説明に反して ─ や ╂ は nil になる。
  def test_type_zen_line_boundaries
    assert_type(Moji::ZEN_LINE, "╰") # U+2570 範囲先頭
    assert_type(Moji::ZEN_LINE, "◿") # U+25FF 範囲末尾
    assert_type(Moji::ZEN_LINE, "▟") # U+259F Block Elements も ZEN_LINE 扱い
    assert_type_nil("╯") # U+256F 範囲の直前
    assert_type_nil("☀") # U+2600 範囲の直後
  end

  def test_type_box_drawing_below_u2570_is_nil
    assert_type_nil("─") # U+2500 いわゆる罫線だが ZEN_LINE にならない
    assert_type_nil("╂") # U+2542 1.8 用フォールバック正規表現 /[─-╂]/ の末尾だが nil
    assert_type_nil("┌") # U+250C
    assert_type_nil("│") # U+2502
  end

  # ZEN_KANJI は uni_range(0x3400,0x4dbf, 0x4e00,0x9fff, 0xf900,0xfaff)。
  def test_type_zen_kanji_boundaries
    assert_type(Moji::ZEN_KANJI, "一") # U+4E00 CJK 統合漢字の先頭
    assert_type(Moji::ZEN_KANJI, "龥") # U+9FA5 旧来の CJK 統合漢字末尾
    assert_type(Moji::ZEN_KANJI, "鿿") # U+9FFF 範囲末尾
    assert_type(Moji::ZEN_KANJI, "㐀")  # U+3400 拡張 A の先頭
    assert_type(Moji::ZEN_KANJI, "䶿")  # U+4DBF 拡張 A の末尾
    assert_type(Moji::ZEN_KANJI, "豈")  # U+F900 互換漢字の先頭
    assert_type(Moji::ZEN_KANJI, "\uFAFF") # U+FAFF 互換漢字の末尾
    assert_type(Moji::ZEN_KANJI, "漢")
    assert_type_nil("\u33FF") # U+33FF 拡張 A の直前
    assert_type_nil("\u4DC0") # U+4DC0 拡張 A の直後（六十四卦）
    assert_type_nil("ꀀ") # U+A000 CJK 統合漢字の直後
    assert_type_nil("\uF8FF") # U+F8FF 互換漢字の直前（私用領域）
    assert_type_nil("ﬀ")      # U+FB00 互換漢字の直後
  end

  # BMP 外（B 面以降）はドキュメントどおり nil。
  def test_type_returns_nil_for_non_bmp_kanji
    assert_type_nil("\u{20000}") # CJK 拡張 B の先頭
    assert_type_nil("\u{2A6DF}")
  end

  # ---------------------------------------------------------------------------
  # 記号リストの全文字走査
  # ---------------------------------------------------------------------------

  def test_type_all_han_asymbol_list_chars
    assert_equal(33, HAN_ASYMBOL_LIST.size)
    HAN_ASYMBOL_LIST.each_char do |ch|
      assert_type(Moji::HAN_ASYMBOL, ch)
    end
  end

  # ZEN_ASYMBOL_LIST は HAN_ASYMBOL_LIST と 1 対 1 対応するので同じ長さ。
  def test_type_all_zen_asymbol_list_chars
    assert_equal(33, ZEN_ASYMBOL_LIST.size)
    ZEN_ASYMBOL_LIST.each_char do |ch|
      assert_type(Moji::ZEN_ASYMBOL, ch)
    end
  end

  def test_type_all_han_jsymbol_list_chars
    assert_equal(8, HAN_JSYMBOL1_LIST.size)
    HAN_JSYMBOL1_LIST.each_char do |ch|
      assert_type(Moji::HAN_JSYMBOL, ch)
    end
  end

  # ZEN_JSYMBOL_LIST には ◇ U+25C7 が 2 回入っている（リスト自体の重複）。
  # 判定結果には影響しないが、リスト長 77 / 異なり 76 という事実も固定する。
  def test_type_all_zen_jsymbol_list_chars
    assert_equal(77, ZEN_JSYMBOL_LIST.size)
    assert_equal(76, ZEN_JSYMBOL_LIST.chars.uniq.size)
    ZEN_JSYMBOL_LIST.each_char do |ch|
      assert_type(Moji::ZEN_JSYMBOL, ch)
    end
  end

  def test_type_all_han_kata_list_chars
    assert_equal(55, HAN_KATA_LIST.size)
    HAN_KATA_LIST.each_char do |ch|
      assert_type(Moji::HAN_KATA, ch)
    end
  end

  def test_type_all_zen_kata_list_chars
    assert_equal([55, 21, 5], ZEN_KATA_LISTS.map(&:size))
    ZEN_KATA_LISTS.each do |list|
      list.each_char do |ch|
        assert_type(Moji::ZEN_KATA, ch)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # CHAR_REGEXPS の走査順に依存する判定
  # ---------------------------------------------------------------------------

  # 仝 U+4EDD は ZEN_KANJI の範囲 U+4E00-U+9FFF に入るが、
  # ZEN_JSYMBOL が CHAR_REGEXPS の先に並んでいるため ZEN_JSYMBOL が勝つ。
  def test_type_scan_order_zen_jsymbol_wins_over_zen_kanji
    assert_type(Moji::ZEN_JSYMBOL, "仝")
  end

  # ○●◎◇◆□■△▲▽▼ は ZEN_LINE の範囲 U+2570-U+25FF に入るが、
  # ZEN_JSYMBOL が先に並んでいるため ZEN_JSYMBOL が勝つ。
  # 走査順が変わると ZEN_LINE になってしまう組み合わせ。
  def test_type_scan_order_zen_jsymbol_wins_over_zen_line
    "○●◎◇◆□■△▲▽▼".each_char do |ch|
      assert_type(Moji::ZEN_JSYMBOL, ch)
    end
  end

  # ---------------------------------------------------------------------------
  # 範囲表（TYPE_RANGE_DATA）と CHAR_REGEXPS の全数一致
  # ---------------------------------------------------------------------------

  # type の実装は CHAR_REGEXPS の走査結果をスナップショットした範囲表の二分探索で、
  # CHAR_REGEXPS 側だけを変更すると両者が黙って乖離する。挿入順走査（最初に
  # マッチした文字種が勝つ）を BMP 全コードポイントで replay し、type の結果と
  # 機械的に突合して乖離を検出する。GoldenFixtures ではなく lib 内の 2 つの表現の
  # 整合性検査なので、公開定数 CHAR_REGEXPS の参照はこのテストに限り許容する。
  def test_type_matches_char_regexps_replay_for_all_bmp_codepoints
    mismatches = []
    (0x0000..0xFFFF).each do |cp|
      next if (0xD800..0xDFFF).cover?(cp) # サロゲートは UTF-8 の文字として存在しない

      ch = cp.chr(Encoding::UTF_8)
      expected = nil
      Moji::CHAR_REGEXPS.each do |tp, reg|
        if ch =~ reg
          expected = tp
          break
        end
      end
      actual = Moji.type(ch)
      mismatches << format("U+%04X: type=%p replay=%p", cp, actual, expected) unless actual == expected
    end
    assert_empty(mismatches)
  end

  # ---------------------------------------------------------------------------
  # nil を返す入力
  # ---------------------------------------------------------------------------

  def test_type_returns_nil_for_hangul
    assert_type_nil("한")
    assert_type_nil("가") # U+AC00 ハングル音節の先頭
    assert_type_nil("ᄀ") # U+1100 ハングル字母
  end

  def test_type_returns_nil_for_non_bmp_characters
    assert_type_nil("😀") # U+1F600 絵文字
    assert_type_nil("\u{1F1EF}") # 地域表示記号
    assert_type_nil("\u{10000}") # B 面の先頭
  end

  def test_type_returns_nil_for_out_of_scope_unicode
    assert_type_nil("é") # U+00E9 ラテン拡張
    assert_type_nil("©") # U+00A9 著作権記号（JIS 記号リスト外）
    assert_type_nil("€") # U+20AC ユーロ記号
    assert_type_nil("\u00A0") # NBSP
    assert_type_nil("\u3099") # 結合文字の濁点
    assert_type_nil("א") # U+05D0 ヘブライ文字
  end

  # ---------------------------------------------------------------------------
  # 文字列長にまつわる挙動
  # ---------------------------------------------------------------------------

  # slice(/\A./m) で先頭 1 文字だけを見る。グラフィムクラスタではなくコードポイント単位。
  def test_type_uses_first_character_of_multi_character_string
    assert_type(Moji::ZEN_KANJI, "漢字")
    assert_type(Moji::HAN_LOWER, "abc")
    assert_type(Moji::ZEN_ASYMBOL, "　ａ")
    assert_type(Moji::ZEN_HIRA, "がっこう")
    assert_type(Moji::HAN_KATA, "ｶﾞ") # 濁点は 2 文字目なので無視される
    assert_type(Moji::ZEN_HIRA, "か\u3099") # か + 結合濁点 U+3099 は 1 グラフィムクラスタだが 2 コードポイント
    assert_type(Moji::HAN_CONTROL, "\nあ")  # /m 付きなので改行も先頭 1 文字として拾う
  end

  def test_type_returns_nil_for_empty_string
    assert_nil(Moji.type(""))
  end

  # ---------------------------------------------------------------------------
  # エンコーディング
  # ---------------------------------------------------------------------------

  def test_type_accepts_non_utf8_encodings
    assert_equal(Moji::ZEN_KANJI, Moji.type("漢".encode("EUC-JP")))
    assert_equal(Moji::HAN_KATA, Moji.type("ｱ".encode("Shift_JIS")))
    assert_equal(Moji::HAN_UPPER, Moji.type("A".encode("EUC-JP")))
    assert_equal(Moji::ZEN_UPPER, Moji.type("Ｂ".encode("EUC-JP")))
    assert_equal(Moji::HAN_UPPER, Moji.type("A".b))
    assert_equal(Moji::HAN_UPPER, Moji.type("A".dup.force_encoding("US-ASCII")))
    assert_nil(Moji.type("".encode("Shift_JIS")))
    assert_nil(Moji.type("".b))
  end

  # UTF-8 に変換できないバイト列は例外が素通しされる。
  def test_type_raises_on_undecodable_binary_string
    assert_raises(Encoding::UndefinedConversionError) do
      Moji.type("\xff".b)
    end
  end

  # ---------------------------------------------------------------------------
  # Moji.type?
  # ---------------------------------------------------------------------------

  def test_type_p_with_single_flag
    assert_equal(true, Moji.type?("Ａ", Moji::ZEN_UPPER))
    assert_equal(false, Moji.type?("Ａ", Moji::HAN_UPPER))
    assert_equal(true, Moji.type?("A", Moji::HAN_UPPER))
    assert_equal(true, Moji.type?("あ", Moji::ZEN_HIRA))
    assert_equal(false, Moji.type?("あ", Moji::ZEN_KATA))
    assert_equal(true, Moji.type?("ヴ", Moji::ZEN_KATA))
    assert_equal(true, Moji.type?("\n", Moji::HAN_CONTROL))
    assert_equal(false, Moji.type?("\n", Moji::HAN_ASYMBOL))
  end

  def test_type_p_with_composite_flags
    assert_equal(true, Moji.type?("Ａ", Moji::ZEN))
    assert_equal(false, Moji.type?("Ａ", Moji::HAN))
    assert_equal(true, Moji.type?("A", Moji::HAN))
    assert_equal(false, Moji.type?("A", Moji::ZEN))
    assert_equal(true, Moji.type?("Ａ", Moji::UPPER))
    assert_equal(true, Moji.type?("Ａ", Moji::ALNUM))
    assert_equal(true, Moji.type?("Ａ", Moji::ALL))
    assert_equal(true, Moji.type?("漢", Moji::KANJI))
    assert_equal(true, Moji.type?("漢", Moji::ZEN))
    assert_equal(true, Moji.type?("\n", Moji::HAN))
    assert_equal(false, Moji.type?("\n", Moji::ZEN))
  end

  def test_type_p_with_kana_flags
    assert_equal(true, Moji.type?("ｱ", Moji::KATA))
    assert_equal(true, Moji.type?("ｱ", Moji::KANA))
    assert_equal(false, Moji.type?("ｱ", Moji::HIRA))
    assert_equal(false, Moji.type?("ｱ", Moji::ZEN_KANA))
    assert_equal(true, Moji.type?("ア", Moji::KATA))
    assert_equal(true, Moji.type?("ア", Moji::ZEN_KANA))
    assert_equal(true, Moji.type?("あ", Moji::HIRA))
    assert_equal(true, Moji.type?("あ", Moji::KANA))
    assert_equal(false, Moji.type?("あ", Moji::KATA))
  end

  def test_type_p_with_symbol_flags
    assert_equal(true, Moji.type?("!", Moji::ASYMBOL))
    assert_equal(true, Moji.type?("!", Moji::SYMBOL))
    assert_equal(true, Moji.type?("!", Moji::HAN_SYMBOL))
    assert_equal(false, Moji.type?("!", Moji::JSYMBOL))
    assert_equal(true, Moji.type?("｡", Moji::JSYMBOL))
    assert_equal(true, Moji.type?("｡", Moji::HAN_SYMBOL))
    assert_equal(false, Moji.type?("｡", Moji::ASYMBOL))
    assert_equal(true, Moji.type?("、", Moji::ZEN_SYMBOL))
  end

  # `|` で合成した一時的なフラグも受け付ける。
  def test_type_p_with_ad_hoc_union
    tp = Moji::HAN_UPPER | Moji::ZEN_UPPER
    assert_equal(true, Moji.type?("Ａ", tp))
    assert_equal(true, Moji.type?("A", tp))
    assert_equal(false, Moji.type?("ａ", tp))
  end

  def test_type_p_accepts_non_utf8_encodings
    assert_equal(true, Moji.type?("Ａ".encode("Shift_JIS"), Moji::ZEN))
    assert_equal(true, Moji.type?("１".encode("EUC-JP"), Moji::NUMBER))
    assert_equal(true, Moji.type?("A".b, Moji::HAN))
  end

  # 本家 1.6 では type が nil のとき nil.to_i == 0 により type? が常に true を
  # 返していた（Flags#include?(nil) の素通し）。v2.1 で修正し、判定不能な文字は
  # どの文字種に対しても false を返す（#3）。
  def test_type_p_returns_false_for_any_type_when_type_is_nil
    unknown = ["한", "😀", "\u{20000}", "é", "─", "Ё", "ヷ", ""]
    types = {
      "HAN" => Moji::HAN,
      "ZEN" => Moji::ZEN,
      "ALL" => Moji::ALL,
      "KANJI" => Moji::KANJI,
      "HIRA" => Moji::HIRA,
      "HAN_CONTROL" => Moji::HAN_CONTROL,
      "ZEN_LINE" => Moji::ZEN_LINE,
    }
    unknown.each do |ch|
      types.each do |name, tp|
        assert_equal(false, Moji.type?(ch, tp), format("type?(%p, %s)", ch, name))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # type が返すフラグオブジェクトの性質（クラスや所属は assert しない）
  # ---------------------------------------------------------------------------

  def test_type_result_equals_constant_and_reports_expected_names
    assert_equal(Moji::HAN_UPPER, Moji.type("A"))
    assert_equal("HAN_UPPER", Moji.type("A").to_s)
    assert_equal("Moji::HAN_UPPER", Moji.type("A").inspect)
    assert_equal("Moji::ZEN_KANJI", Moji.type("漢").inspect)
    assert_equal(1, Moji::HAN_CONTROL.to_i)
    assert_equal(1 << 17, Moji::ZEN_KANJI.to_i)
    assert_equal(127, Moji::HAN.to_i)
    assert_equal(262_016, Moji::ZEN.to_i)
    assert_equal(262_143, Moji::ALL.to_i)
  end

  # 別名定数は元の定数と等しい。
  def test_alias_constants_equal_their_sources
    assert_equal(Moji::ZEN_HIRA, Moji::HIRA)
    assert_equal(Moji::ZEN_GREEK, Moji::GREEK)
    assert_equal(Moji::ZEN_CYRILLIC, Moji::CYRILLIC)
    assert_equal(Moji::ZEN_LINE, Moji::LINE)
    assert_equal(Moji::ZEN_KANJI, Moji::KANJI)
  end

  # 合成定数の inspect は含まれるフラグ名を | でつないで返す。
  def test_composite_flag_inspect_strings
    assert_equal("Moji::(HAN_KATA|ZEN_KATA)", Moji::KATA.inspect)
    assert_equal("Moji::(HAN_KATA|ZEN_HIRA|ZEN_KATA)", Moji::KANA.inspect)
    assert_equal(
      "Moji::(HAN_CONTROL|HAN_ASYMBOL|HAN_JSYMBOL|HAN_NUMBER|HAN_UPPER|HAN_LOWER|HAN_KATA)",
      Moji::HAN.inspect
    )
  end
end
