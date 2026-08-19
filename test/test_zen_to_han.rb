# frozen_string_literal: true

require "test_helper"

# Moji.zen_to_han のゴールデンテスト。
# 期待値はすべて現行リリースの意図した挙動を実測して固定したもの（本家 1.6 互換）。
# 直感に反する挙動もそのまま期待値としている（各テストの注記コメント参照）。
class MojiZenToHanTest < Minitest::Test
  # 対応表の正データ（ZEN_TO_HAN_*_PAIRS / ZEN_JSYMBOL_UNCONVERTED_CHARS）は
  # test_helper の GoldenFixtures に集約している
  # （lib の Detail は private 実装なので参照しない）。
  include GoldenFixtures

  # 全文字種を 1 つずつ含むスコープ検証用の入力。
  MIXED_SOURCE = "Ａｂ１！　。ー・ガパヴあ漢ヮヶ±"

  # --- デフォルト（type 引数なし = ALL）での代表変換 ---

  def test_default_converts_alnum_and_symbols
    assert_equal("Ruby!?", Moji.zen_to_han("Ｒｕｂｙ！？"))
    assert_equal("ABC123abc", Moji.zen_to_han("ＡＢＣ１２３ａｂｃ"))
  end

  def test_default_converts_mixed_japanese_sentence
    # ひらがな・漢字は変換対象外なのでそのまま残る。
    assert_equal(
      "ﾄﾞﾗえもん(Doraemon)は､日本で1番有名な漫画だ｡",
      Moji.zen_to_han("ドラえもん(Doraemon)は、日本で1番有名な漫画だ。")
    )
  end

  def test_default_converts_katakana_with_prolonged_sound_mark
    # ー は ZEN_JSYMBOL なので ALL では ｰ になる。
    assert_equal("ｳﾞｧｲｵﾘﾝ", Moji.zen_to_han("ヴァイオリン"))
    assert_equal("ﾊﾟｰﾃｨｰ", Moji.zen_to_han("パーティー"))
  end

  def test_default_converts_ideographic_space
    # 全角スペースは ZEN_ASYMBOL_LIST に属する。
    assert_equal(" ", Moji.zen_to_han("　"))
  end

  # --- 全角カタカナ → 半角カタカナの全文字対応表 ---

  def test_all_zen_katakana_chars_convert_to_han_katakana
    ZEN_TO_HAN_KATA_PAIRS.each do |zen, han|
      assert_equal(han, Moji.zen_to_han(zen), "zen_to_han(#{zen.inspect})")
    end
  end

  def test_katakana_block_conversion_coverage_is_exhaustive
    # ァ(U+30A1)〜ヶ(U+30F6) の 86 文字のうち、変換されずに残るのはこの 5 文字だけ。
    # 残り 81 文字は上の対応表で全て変換される。
    range = (("ァ".ord)..("ヶ".ord)).map { |cp| cp.chr(Encoding::UTF_8) }
    unchanged = range.select { |ch| Moji.zen_to_han(ch) == ch }
    assert_equal(%w[ヮ ヰ ヱ ヵ ヶ], unchanged)
    assert_equal(ZEN_TO_HAN_KATA_PAIRS.size, range.size - unchanged.size)
  end

  def test_dakuten_and_handakuten_are_decomposed_into_two_chars
    # 濁音・半濁音は必ず「半角カナ 1 文字 + ﾞ/ﾟ」の 2 文字になる。
    assert_equal("ﾊﾞ", Moji.zen_to_han("バ"))
    assert_equal("ﾊﾟ", Moji.zen_to_han("パ"))
    assert_equal("ｳﾞ", Moji.zen_to_han("ヴ"))
    assert_equal("ｶﾞｷﾞｸﾞｹﾞｺﾞ", Moji.zen_to_han("ガギグゲゴ"))
    assert_equal("ﾊﾟﾋﾟﾌﾟﾍﾟﾎﾟ", Moji.zen_to_han("パピプペポ"))
    assert_equal("ﾊﾞﾋﾞﾌﾞﾍﾞﾎﾞ", Moji.zen_to_han("バビブベボ"))
  end

  # --- 変換表に無い全角カナ ---

  def test_katakana_not_in_conversion_table_is_left_as_is
    # ヮ ヵ ヶ ヰ ヱ と、合成用の ヷヸヹヺ は変換表に無いため ALL でも変換されない。
    # （ヮ ヵ ヶ は Moji.type 上は ZEN_KATA と判定されるが変換されない）
    assert_equal("ヮヵヶヰヱ", Moji.zen_to_han("ヮヵヶヰヱ"))
    assert_equal("ヷヸヹヺ", Moji.zen_to_han("ヷヸヹヺ"))
    assert_equal(Moji::ZEN_KATA, Moji.type("ヮ"))
    assert_equal(Moji::ZEN_KATA, Moji.type("ヶ"))
  end

  def test_prolonged_sound_mark_is_jsymbol_not_katakana
    # ー は ZEN_JSYMBOL 扱い。ZEN_KATA だけを指定すると全角のまま残り、幅が混在する。
    assert_equal(Moji::ZEN_JSYMBOL, Moji.type("ー"))
    assert_equal("ー", Moji.zen_to_han("ー", Moji::ZEN_KATA))
    assert_equal("ｰ", Moji.zen_to_han("ー", Moji::ZEN_JSYMBOL))
    assert_equal("ﾊﾞーｶﾞー", Moji.zen_to_han("バーガー", Moji::ZEN_KATA))
  end

  # --- type 引数によるスコープ ---

  def test_scope_all
    assert_equal("Ab1! ｡ｰ･ｶﾞﾊﾟｳﾞあ漢ヮヶ±", Moji.zen_to_han(MIXED_SOURCE, Moji::ALL))
  end

  def test_scope_default_equals_all
    assert_equal(Moji.zen_to_han(MIXED_SOURCE, Moji::ALL), Moji.zen_to_han(MIXED_SOURCE))
  end

  def test_scope_zen_lower_only
    assert_equal("Ａb１！　。ー・ガパヴあ漢ヮヶ±", Moji.zen_to_han(MIXED_SOURCE, Moji::ZEN_LOWER))
  end

  def test_scope_zen_upper_only
    assert_equal("Aｂ１！　。ー・ガパヴあ漢ヮヶ±", Moji.zen_to_han(MIXED_SOURCE, Moji::ZEN_UPPER))
    assert_equal("ＡＢ", Moji.zen_to_han("ＡＢ", Moji::ZEN_LOWER))
  end

  def test_scope_zen_number_only
    assert_equal("Ａｂ1！　。ー・ガパヴあ漢ヮヶ±", Moji.zen_to_han(MIXED_SOURCE, Moji::ZEN_NUMBER))
  end

  def test_scope_zen_asymbol_only
    # 全角スペースも ZEN_ASYMBOL なので半角スペースになる。
    assert_equal("Ａｂ１! 。ー・ガパヴあ漢ヮヶ±", Moji.zen_to_han(MIXED_SOURCE, Moji::ZEN_ASYMBOL))
  end

  def test_scope_zen_jsymbol_only
    assert_equal("Ａｂ１！　｡ｰ･ガパヴあ漢ヮヶ±", Moji.zen_to_han(MIXED_SOURCE, Moji::ZEN_JSYMBOL))
  end

  def test_scope_zen_kata_only
    assert_equal("Ａｂ１！　。ー・ｶﾞﾊﾟｳﾞあ漢ヮヶ±", Moji.zen_to_han(MIXED_SOURCE, Moji::ZEN_KATA))
  end

  def test_scope_zen_alnum
    assert_equal("Ab1！　。ー・ガパヴあ漢ヮヶ±", Moji.zen_to_han(MIXED_SOURCE, Moji::ZEN_ALNUM))
    assert_equal("12abAB", Moji.zen_to_han("１２ａｂＡＢ", Moji::ZEN_ALNUM))
  end

  def test_scope_zen_alnum_or_zen_asymbol
    assert_equal(
      "Ab1! 。ー・ガパヴあ漢ヮヶ±",
      Moji.zen_to_han(MIXED_SOURCE, Moji::ZEN_ALNUM | Moji::ZEN_ASYMBOL)
    )
  end

  def test_scope_zen_covers_everything_all_does
    # ZEN は半角側のフラグを含まないが、zen_to_han の結果は ALL と同じ。
    assert_equal(Moji.zen_to_han(MIXED_SOURCE, Moji::ALL), Moji.zen_to_han(MIXED_SOURCE, Moji::ZEN))
  end

  def test_scope_alpha_converts_only_alphabets
    assert_equal("Ruby！？", Moji.zen_to_han("Ｒｕｂｙ！？", Moji::ALPHA))
  end

  def test_scope_alnum_or_asymbol
    assert_equal("Ruby!?", Moji.zen_to_han("Ｒｕｂｙ！？", Moji::ALNUM | Moji::ASYMBOL))
  end

  def test_scope_han_only_converts_nothing
    # 半角側のフラグだけを渡しても全角は一切変換されない。
    assert_equal(MIXED_SOURCE, Moji.zen_to_han(MIXED_SOURCE, Moji::HAN))
  end

  def test_scope_zen_hira_and_zen_kanji_convert_nothing
    # ひらがな・漢字には対応する半角が無いので、指定しても何も起きない。
    assert_equal(MIXED_SOURCE, Moji.zen_to_han(MIXED_SOURCE, Moji::ZEN_HIRA))
    assert_equal(MIXED_SOURCE, Moji.zen_to_han(MIXED_SOURCE, Moji::ZEN_KANJI))
  end

  # --- ZEN_ASYMBOL_LIST の全文字対応 ---

  def test_all_zen_asymbol_chars_convert_one_to_one
    ZEN_TO_HAN_ASYMBOL_PAIRS.each do |zen, han|
      assert_equal(han, Moji.zen_to_han(zen), "zen_to_han(#{zen.inspect})")
    end
  end

  def test_zen_asymbol_notable_mappings
    # ￥(U+FFE5) → \ 、￣(U+FFE3) → ~ 、‘(U+2018) → ` という非自明な対応。
    assert_equal("\\", Moji.zen_to_han("￥"))
    assert_equal("~", Moji.zen_to_han("￣"))
    assert_equal("`", Moji.zen_to_han("‘"))
    assert_equal("\"", Moji.zen_to_han("”"))
    assert_equal("'", Moji.zen_to_han("’"))
    # 一方 ＼(U+FF3C) ～(U+FF5E) 〜(U+301C) “ ｀(U+FF40) は対応表に無く変換されない。
    assert_equal("“｀～〜＼", Moji.zen_to_han("“｀～〜＼"))
  end

  # --- ZEN_JSYMBOL1 の対応と、JSYMBOL1 に無い文字 ---

  def test_zen_jsymbol1_chars_convert
    ZEN_TO_HAN_JSYMBOL1_PAIRS.each do |zen, han|
      assert_equal(han, Moji.zen_to_han(zen), "zen_to_han(#{zen.inspect})")
      assert_equal(han, Moji.zen_to_han(zen, Moji::ZEN_JSYMBOL), "scoped #{zen.inspect}")
    end
    assert_equal("｡｢｣､ｰﾞﾟ･", Moji.zen_to_han("。「」、ー゛゜・"))
  end

  def test_zen_jsymbol_chars_outside_jsymbol1_are_not_converted
    ZEN_JSYMBOL_UNCONVERTED_CHARS.each do |ch|
      assert_equal(ch, Moji.zen_to_han(ch), "zen_to_han(#{ch.inspect})")
      assert_equal(ch, Moji.zen_to_han(ch, Moji::ZEN_JSYMBOL), "scoped #{ch.inspect}")
    end
    assert_equal("±×÷", Moji.zen_to_han("±×÷"))
  end

  # --- カタカナ変換が JSYMBOL 変換より先に走る（ソースのコメント参照） ---

  def test_katakana_conversion_runs_before_jsymbol_conversion
    # 「カ + 全角濁点」は ALL では合成済みの「ガ」と同じ ｶﾞ になる。
    assert_equal("ｶﾞ", Moji.zen_to_han("カ゛"))
    assert_equal("ｶﾞ", Moji.zen_to_han("ガ"))
    assert_equal("ﾊﾟ", Moji.zen_to_han("ハ゜"))
    # スコープを片方に絞ると幅が混在する。
    assert_equal("ｶ゛", Moji.zen_to_han("カ゛", Moji::ZEN_KATA))
    assert_equal("カﾞ", Moji.zen_to_han("カ゛", Moji::ZEN_JSYMBOL))
  end

  # --- 変換対象を含まない入力 ---

  def test_empty_string_returns_empty_string
    assert_equal("", Moji.zen_to_han(""))
    assert_equal("", Moji.zen_to_han("", Moji::ZEN_KATA))
    assert_equal("", Moji.zen_to_han("", Moji::HAN))
  end

  def test_hiragana_and_kanji_only_string_is_unchanged
    assert_equal("ひらがな漢字", Moji.zen_to_han("ひらがな漢字"))
    assert_equal("あいうえお", Moji.zen_to_han("あいうえお"))
  end

  def test_already_han_string_is_unchanged
    assert_equal("Ruby 1.9!", Moji.zen_to_han("Ruby 1.9!"))
    assert_equal("ｶﾞ", Moji.zen_to_han("ｶﾞ"))
  end

  # --- 返値の同一性・引数の非破壊性 ---

  def test_returns_new_string_when_conversion_branches_run
    input = "あいう"
    result = Moji.zen_to_han(input)
    assert_equal("あいう", result)
    # 内容が変わらなくても、変換分岐が走る限り新しい String が返る。
    refute_same(input, result)
  end

  def test_returns_the_argument_itself_when_no_branch_runs
    # 変換分岐が 1 つも走らない type を渡すと、引数のオブジェクトがそのまま返る。
    # （「常に新しい文字列を返す」わけではない。frozen な入力は frozen のまま返る）
    input = "あいう"
    assert_same(input, Moji.zen_to_han(input, Moji::HAN))
    assert_same(input, Moji.zen_to_han(input, Moji::ZEN_HIRA))
    assert_same(input, Moji.zen_to_han(input, Moji::ZEN_KANJI))
    assert(Moji.zen_to_han(input, Moji::HAN).frozen?) # 入力がリテラル(frozen)なので frozen
  end

  def test_non_utf8_input_never_returns_the_argument_itself
    # 非 UTF-8 入力は元エンコーディングへ encode し直す経路を通るため、
    # 変換分岐が 1 つも走らなくても必ず別オブジェクトになる（frozen も伝播しない）。
    input = "あいう".encode("Windows-31J").freeze
    result = Moji.zen_to_han(input, Moji::HAN)
    refute_same(input, result)
    assert_equal(input, result)
    refute(result.frozen?)
  end

  def test_does_not_mutate_argument
    input = +"Ａｂ１ガ。！"
    snapshot = input.dup
    Moji.zen_to_han(input)
    assert_equal(snapshot, input)
    Moji.zen_to_han(input, Moji::ZEN_KATA)
    assert_equal(snapshot, input)
  end

  # --- 非 UTF-8 エンコーディング ---

  def test_preserves_argument_encoding
    sjis = "Ａｂ１！ガパ。".encode("Windows-31J")
    result = Moji.zen_to_han(sjis)
    assert_equal(Encoding::Windows_31J, result.encoding)
    assert_equal("Ab1!ｶﾞﾊﾟ｡", result.encode("UTF-8"))

    euc = "Ａｂガ".encode("EUC-JP")
    euc_result = Moji.zen_to_han(euc)
    assert_equal(Encoding::EUC_JP, euc_result.encoding)
    assert_equal("Abｶﾞ", euc_result.encode("UTF-8"))
  end
end
