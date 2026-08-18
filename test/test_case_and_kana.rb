# frozen_string_literal: true

require "test_helper"

# Moji.upcase / Moji.downcase / Moji.kata_to_hira / Moji.hira_to_kata の
# 現行実装（本家 1.6 相当）の実挙動を固定するゴールデンテスト。
# 期待値はすべて現行実装を実行して得た実測値であり、直感に反するもの
# （バグに見えるもの）もそのまま固定する。
class TestCaseAndKana < Minitest::Test
  include MojiTestHelpers

  # tr("ァ-ン", "ぁ-ん") の変換対象となる全カタカナ（U+30A1 ァ 〜 U+30F3 ン）。
  KATA_IN_RANGE =
    "ァアィイゥウェエォオカガキギクグケゲコゴサザシジスズセゼソゾタダチヂッツヅテデトド" \
    "ナニヌネノハバパヒビピフブプヘベペホボポマミムメモャヤュユョヨラリルレロヮワヰヱヲン"

  # 上を kata_to_hira にかけた実測結果（U+3041 ぁ 〜 U+3093 ん）。
  HIRA_IN_RANGE =
    "ぁあぃいぅうぇえぉおかがきぎくぐけげこごさざしじすずせぜそぞただちぢっつづてでとど" \
    "なにぬねのはばぱひびぴふぶぷへべぺほぼぽまみむめもゃやゅゆょよらりるれろゎわゐゑをん"

  # ン（U+30F3）より後ろのカタカナブロック（U+30F4 〜 U+30FF）。tr の範囲外。
  KATA_OUT_OF_RANGE = "ヴヵヶヷヸヹヺ・ーヽヾヿ"

  # ん（U+3093）より後ろのひらがなブロック（U+3094 〜 U+309F）。tr の範囲外。
  # U+3097 / U+3098 は未割り当て、U+3099 / U+309A は結合用の濁点・半濁点。
  HIRA_OUT_OF_RANGE = "ゔゕゖ゗゘゙゚゛゜ゝゞゟ"

  # ---------------------------------------------------------------- upcase

  def test_upcase_default_converts_both_han_and_zen_lower
    # デフォルトの type は LOWER（HAN_LOWER | ZEN_LOWER）。
    assert_equal "ABCXYZ", Moji.upcase("abcxyz")
    assert_equal "ＡＢＣＺ", Moji.upcase("ａｂｃｚ")
    assert_equal "ABCＸＹＺＡＢＣ", Moji.upcase("abcＸＹＺａｂｃ")
  end

  def test_upcase_doc_example
    # リファレンスドキュメント記載の例。
    assert_equal "ＲＵＢＹ", Moji.upcase("Ｒｕｂｙ")
  end

  def test_upcase_with_han_lower_only
    # 半角小文字だけが対象。全角小文字はそのまま残る。
    assert_equal "ABCａｂｃ", Moji.upcase("abcａｂｃ", Moji::HAN_LOWER)
  end

  def test_upcase_with_zen_lower_only
    # 全角小文字だけが対象。半角小文字はそのまま残る。
    assert_equal "abcＡＢＣ", Moji.upcase("abcａｂｃ", Moji::ZEN_LOWER)
    assert_equal "abc", Moji.upcase("abc", Moji::ZEN_LOWER)
  end

  def test_upcase_with_alpha_type_converts_both
    # ALPHA は HAN_LOWER と ZEN_LOWER の両方を含むのでデフォルトと同じ結果になる。
    assert_equal "ABCＡＢＣ", Moji.upcase("abcａｂｃ", Moji::ALPHA)
  end

  def test_upcase_with_all_type_converts_both
    assert_equal "ABC", Moji.upcase("abc", Moji::ALL)
  end

  def test_upcase_with_type_not_including_lower_changes_nothing
    # UPPER / KANA のように *_LOWER を含まない type では何も変換されない。
    assert_equal "abcａｂｃ", Moji.upcase("abcａｂｃ", Moji::UPPER)
    assert_equal "abcａｂｃ", Moji.upcase("abcａｂｃ", Moji::KANA)
  end

  def test_upcase_leaves_upper_number_kana_and_kanji_unchanged
    assert_equal "ABC０９あアン漢", Moji.upcase("ABC０９あアン漢")
  end

  def test_upcase_does_not_convert_greek_or_cyrillic
    # ドキュメント記載の制限: ギリシャ文字・キリル文字には対応しない。
    assert_equal "αβγΑΒΓ", Moji.upcase("αβγΑΒΓ")
    assert_equal "абвАБВ", Moji.upcase("абвАБВ")
  end

  def test_upcase_accepts_frozen_string
    # 破壊的変更（tr!）ではないので凍結文字列でも動く。
    assert_equal "ABCＡＢＣ", Moji.upcase("abcａｂｃ")
  end

  def test_upcase_of_empty_string
    assert_equal "", Moji.upcase("")
  end

  def test_upcase_preserves_input_encoding
    result = Moji.upcase("ａｂｃdef".encode("Windows-31J"))

    assert_equal "Windows-31J", result.encoding.name
    assert_equal "ＡＢＣDEF", result.encode("UTF-8")

    ascii = Moji.upcase("abc".encode("US-ASCII"))

    assert_equal "US-ASCII", ascii.encoding.name
    assert_equal "ABC", ascii
  end

  # -------------------------------------------------------------- downcase

  def test_downcase_default_converts_both_han_and_zen_upper
    # デフォルトの type は UPPER（HAN_UPPER | ZEN_UPPER）。
    assert_equal "abcxyz", Moji.downcase("ABCXYZ")
    assert_equal "ａｂｃｚ", Moji.downcase("ＡＢＣＺ")
    assert_equal "abcａｂｃａｂｃ", Moji.downcase("ABCａｂｃＡＢＣ")
  end

  def test_downcase_doc_example
    # リファレンスドキュメント記載の例。
    assert_equal "ｒｕｂｙ", Moji.downcase("Ｒｕｂｙ")
  end

  def test_downcase_with_han_upper_only
    assert_equal "abcＡＢＣ", Moji.downcase("ABCＡＢＣ", Moji::HAN_UPPER)
  end

  def test_downcase_with_zen_upper_only
    assert_equal "ABCａｂｃ", Moji.downcase("ABCＡＢＣ", Moji::ZEN_UPPER)
    assert_equal "ABC", Moji.downcase("ABC", Moji::ZEN_UPPER)
  end

  def test_downcase_with_alpha_type_converts_both
    assert_equal "abcａｂｃ", Moji.downcase("ABCＡＢＣ", Moji::ALPHA)
  end

  def test_downcase_with_all_type_converts_both
    assert_equal "abc", Moji.downcase("ABC", Moji::ALL)
  end

  def test_downcase_with_type_not_including_upper_changes_nothing
    assert_equal "ABCＡＢＣ", Moji.downcase("ABCＡＢＣ", Moji::LOWER)
    assert_equal "ABCＡＢＣ", Moji.downcase("ABCＡＢＣ", Moji::KANA)
  end

  def test_downcase_leaves_lower_number_kana_and_kanji_unchanged
    assert_equal "abc０９あアン漢", Moji.downcase("abc０９あアン漢")
  end

  def test_downcase_does_not_convert_greek_or_cyrillic
    # ドキュメント記載の制限: ギリシャ文字・キリル文字には対応しない。
    assert_equal "αβγΑΒΓ", Moji.downcase("αβγΑΒΓ")
    assert_equal "абвАБВ", Moji.downcase("абвАБВ")
  end

  def test_downcase_accepts_frozen_string
    assert_equal "abcａｂｃ", Moji.downcase("ABCＡＢＣ")
  end

  def test_downcase_of_empty_string
    assert_equal "", Moji.downcase("")
  end

  def test_downcase_preserves_input_encoding
    result = Moji.downcase("ＡＢＣDEF".encode("EUC-JP"))

    assert_equal "EUC-JP", result.encoding.name
    assert_equal "ａｂｃdef", result.encode("UTF-8")
  end

  def test_upcase_result_does_not_depend_on_default_internal
    with_default_internal(Encoding::UTF_8) do
      assert_equal "ＡBC", Moji.upcase("ａbc")
    end
  end

  # --------------------------------------------------------- kata_to_hira

  def test_kata_to_hira_doc_example
    assert_equal "るびー", Moji.kata_to_hira("ルビー")
  end

  def test_kata_to_hira_converts_whole_in_range_block
    # tr("ァ-ン", "ぁ-ん") が変換する U+30A1〜U+30F3 の全カタカナ。
    # ヮ・ヰ・ヱ も範囲内なので ゎ・ゐ・ゑ に変換される。
    assert_equal HIRA_IN_RANGE, Moji.kata_to_hira(KATA_IN_RANGE)
  end

  def test_kata_to_hira_leaves_out_of_range_katakana_unchanged
    # ン（U+30F3）より後ろは範囲外なので一切変換されない。
    assert_equal KATA_OUT_OF_RANGE, Moji.kata_to_hira(KATA_OUT_OF_RANGE)
    assert_equal "ヴ", Moji.kata_to_hira("ヴ")
    assert_equal "ヵ", Moji.kata_to_hira("ヵ")
    assert_equal "ヶ", Moji.kata_to_hira("ヶ")
    assert_equal "ヷヸヹヺ", Moji.kata_to_hira("ヷヸヹヺ")
    assert_equal "・", Moji.kata_to_hira("・")
    assert_equal "ー", Moji.kata_to_hira("ー")
    assert_equal "ヽヾ", Moji.kata_to_hira("ヽヾ")
    assert_equal "ヿ", Moji.kata_to_hira("ヿ")
  end

  def test_kata_to_hira_leaves_char_below_range_unchanged
    # ァ（U+30A1）の直前 U+30A0（片仮名平仮名二重ハイフン）も範囲外。
    assert_equal "゠", Moji.kata_to_hira("゠")
  end

  def test_kata_to_hira_does_not_convert_han_kata
    # ドキュメント記載どおり半角カタカナは変換されない。
    assert_equal "ﾊﾝｶｸｶﾅ", Moji.kata_to_hira("ﾊﾝｶｸｶﾅ")
    assert_equal "ｱｲｳｴｵｶﾞﾊﾟ", Moji.kata_to_hira("ｱｲｳｴｵｶﾞﾊﾟ")
  end

  def test_kata_to_hira_leaves_hiragana_unchanged
    assert_equal "ひらがな", Moji.kata_to_hira("ひらがな")
  end

  def test_kata_to_hira_converts_only_zen_kata_in_mixed_string
    assert_equal "かたかなとｶﾀｶﾅと漢字ABC123ａｂｃ！",
                 Moji.kata_to_hira("カタカナとｶﾀｶﾅと漢字ABC123ａｂｃ！")
    assert_equal "どらえもん(Doraemon)は、日本で1番有名な漫画だ。",
                 Moji.kata_to_hira("ドラえもん(Doraemon)は、日本で1番有名な漫画だ。")
  end

  def test_kata_to_hira_mixes_scripts_when_vu_is_present
    # ヴ だけ範囲外に取り残されるので、出力がカタカナとひらがなの混在になる。
    assert_equal "ヴぁいおりん", Moji.kata_to_hira("ヴァイオリン")
  end

  def test_kata_to_hira_of_empty_string
    assert_equal "", Moji.kata_to_hira("")
  end

  def test_kata_to_hira_accepts_frozen_string
    assert_equal "あいう", Moji.kata_to_hira("アイウ")
  end

  def test_kata_to_hira_preserves_input_encoding
    result = Moji.kata_to_hira("カタカナ".encode("EUC-JP"))

    assert_equal "EUC-JP", result.encoding.name
    assert_equal "かたかな", result.encode("UTF-8")
  end

  # --------------------------------------------------------- hira_to_kata

  def test_hira_to_kata_doc_example
    assert_equal "ルビー", Moji.hira_to_kata("るびー")
  end

  def test_hira_to_kata_converts_whole_in_range_block
    # tr("ぁ-ん", "ァ-ン") が変換する U+3041〜U+3093 の全ひらがな。
    assert_equal KATA_IN_RANGE, Moji.hira_to_kata(HIRA_IN_RANGE)
  end

  def test_hira_to_kata_leaves_out_of_range_hiragana_unchanged
    # ん（U+3093）より後ろは範囲外なので一切変換されない。
    assert_equal HIRA_OUT_OF_RANGE, Moji.hira_to_kata(HIRA_OUT_OF_RANGE)
    assert_equal "ゔ", Moji.hira_to_kata("ゔ")
    assert_equal "ゕ", Moji.hira_to_kata("ゕ")
    assert_equal "ゖ", Moji.hira_to_kata("ゖ")
    assert_equal "゛゜", Moji.hira_to_kata("゛゜")
    assert_equal "ゝゞ", Moji.hira_to_kata("ゝゞ")
    assert_equal "ゟ", Moji.hira_to_kata("ゟ")
  end

  def test_hira_to_kata_leaves_char_below_range_unchanged
    # ぁ（U+3041）の直前 U+3040（未割り当て）も範囲外。
    assert_equal "぀", Moji.hira_to_kata("぀")
  end

  def test_hira_to_kata_does_not_convert_han_kata
    assert_equal "ｱｲｳｴｵｶﾞﾊﾟ", Moji.hira_to_kata("ｱｲｳｴｵｶﾞﾊﾟ")
  end

  def test_hira_to_kata_leaves_katakana_unchanged
    assert_equal "カタカナ", Moji.hira_to_kata("カタカナ")
  end

  def test_hira_to_kata_converts_only_hiragana_in_mixed_string
    assert_equal "ヒラガナトｶﾀｶﾅト漢字abc123ＡＢＣ！",
                 Moji.hira_to_kata("ひらがなとｶﾀｶﾅと漢字abc123ＡＢＣ！")
    assert_equal "ドラエモン(Doraemon)ハ、日本デ1番有名ナ漫画ダ。",
                 Moji.hira_to_kata("ドラえもん(Doraemon)は、日本で1番有名な漫画だ。")
  end

  def test_hira_to_kata_mixes_scripts_when_vu_is_present
    # ゔ だけ範囲外に取り残される。
    assert_equal "ゔァイオリン", Moji.hira_to_kata("ゔぁいおりん")
  end

  def test_hira_to_kata_of_empty_string
    assert_equal "", Moji.hira_to_kata("")
  end

  def test_hira_to_kata_accepts_frozen_string
    assert_equal "アイウ", Moji.hira_to_kata("あいう")
  end

  def test_hira_to_kata_preserves_input_encoding
    result = Moji.hira_to_kata("ひらがな".encode("Windows-31J"))

    assert_equal "Windows-31J", result.encoding.name
    assert_equal "ヒラガナ", result.encode("UTF-8")
  end

  # ---------------------------------------------------------- 往復変換

  def test_round_trip_is_identity_for_in_range_katakana
    assert_equal KATA_IN_RANGE, Moji.hira_to_kata(Moji.kata_to_hira(KATA_IN_RANGE))
  end

  def test_round_trip_is_identity_for_in_range_hiragana
    assert_equal HIRA_IN_RANGE, Moji.kata_to_hira(Moji.hira_to_kata(HIRA_IN_RANGE))
  end

  def test_round_trip_is_identity_for_out_of_range_kana
    # 範囲外の文字はどちらの向きでも動かないので往復しても不変。
    assert_equal "ヴァイオリン", Moji.hira_to_kata(Moji.kata_to_hira("ヴァイオリン"))
    assert_equal "ゔぁいおりん", Moji.kata_to_hira(Moji.hira_to_kata("ゔぁいおりん"))
    assert_equal "ヵヶヽヾ", Moji.hira_to_kata(Moji.kata_to_hira("ヵヶヽヾ"))
  end

  def test_round_trip_is_not_identity_for_mixed_script_text
    # かなとカナが混在した文字列は片方に潰れるので元に戻らない。
    assert_equal "ああ", Moji.kata_to_hira(Moji.hira_to_kata("あア"))
    assert_equal "アア", Moji.hira_to_kata(Moji.kata_to_hira("あア"))
    assert_equal "ドラエモン", Moji.hira_to_kata(Moji.kata_to_hira("ドラえもん"))
  end
end
