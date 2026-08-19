# frozen_string_literal: true

require "test_helper"

# nfc: キーワード引数(v2.1 で追加。#1)のテスト。
# 期待値は issue #1 の実測に基づく。nfc は既定 off のオプトインであり、
# 省略時の挙動が従来と一致することもここで固定する。
# NFD/NFC のリテラルはエディタ上で見た目の区別がつかない(隣接行に同じ見た目で
# 別コードポイントの「が」が並ぶ)。このファイルを編集したら、文字列リテラルの
# 実コードポイントを ruby で列挙して意図と一致するか機械検証すること。
class TestNfc < Minitest::Test
  NFD_GA = "ガ" # NFD の「ガ」(カ + 結合濁点)
  HAN_KA_COMBINING = "ｶ゙" # 半角カナの ｶ + 全角の結合濁点
  NFD_E_ACUTE = "é" # NFD の「é」(e + 結合アクセント)

  def codepoints(str)
    str.codepoints.map { |c| format("U+%04X", c) }.join(" ")
  end

  # ---- zen_to_han ----

  def test_zen_to_han_with_nfc_converts_nfd_zen_kata_to_encodable_han_kata
    result = Moji.zen_to_han(NFD_GA, nfc: true)
    assert_equal("ｶﾞ", result, codepoints(result)) # ｶﾞ(半角の濁点)
    # NFD 入力の半角化結果がレガシーエンコーディングへ変換できることが本機能の眼目。
    assert_equal([0xB6, 0xDE], result.encode(Encoding::Windows_31J).bytes)
  end

  def test_zen_to_han_default_preserves_legacy_broken_sequence
    # 既定では本家同様「半角カナ + 全角結合濁点」という CP932 へ変換できない列が生じる。
    result = Moji.zen_to_han(NFD_GA)
    assert_equal(HAN_KA_COMBINING, result, codepoints(result))
    assert_raises(Encoding::UndefinedConversionError) { result.encode(Encoding::Windows_31J) }
  end

  def test_zen_to_han_with_nfc_cannot_fix_han_kata_with_combining_mark
    # 既知の限界: 入力が既に「半角カナ + 結合濁点」の場合、zen_to_han は半角カナを
    # 変換対象にせず、NFC もこの組を合成できないため、nfc: true でも塞がらない。
    result = Moji.zen_to_han(HAN_KA_COMBINING, nfc: true)
    assert_equal(HAN_KA_COMBINING, result, codepoints(result))
    assert_raises(Encoding::UndefinedConversionError) { result.encode(Encoding::Windows_31J) }
  end

  # ---- normalize_zen_han ----

  def test_normalize_zen_han_with_nfc_converges_all_four_forms_of_ga
    # 見た目が同じ「ガ」の 4 表現が単一の合成済みコードポイント U+30AC へ収束する。
    ["ｶﾞ", HAN_KA_COMBINING, "ガ", NFD_GA].each do |input|
      result = Moji.normalize_zen_han(input, nfc: true)
      assert_equal("ガ", result, "input: #{codepoints(input)} -> #{codepoints(result)}")
    end
  end

  def test_normalize_zen_han_default_preserves_normalization_form_differences
    # 既定では入力の正規化形の違いが出力へ持ち越される(従来挙動の固定)。
    assert_equal("ガ", Moji.normalize_zen_han("ｶﾞ"))
    assert_equal(NFD_GA, Moji.normalize_zen_han(HAN_KA_COMBINING))
  end

  # ---- type / type? ----

  def test_type_with_nfc_classifies_by_composed_form
    # e + 結合アクセントは NFC で é(U+00E9) に合成され、分類外(nil)になる。
    # 既定では基底文字 e で判定され HAN_LOWER。同じ見た目でも結果が分かれる。
    assert_equal(Moji::HAN_LOWER, Moji.type(NFD_E_ACUTE))
    assert_nil(Moji.type(NFD_E_ACUTE, nfc: true))
  end

  def test_type_p_with_nfc_follows_composed_classification
    assert_equal(true, Moji.type?(NFD_E_ACUTE, Moji::HAN_LOWER))
    assert_equal(false, Moji.type?(NFD_E_ACUTE, Moji::HAN_LOWER, nfc: true))
    # NFD の全角カナは合成後も ZEN_KATA のまま(基底文字判定と結果が一致する例)。
    assert_equal(true, Moji.type?(NFD_GA, Moji::ZEN_KATA, nfc: true))
  end

  # ---- かな変換 ----

  def test_kata_to_hira_with_nfc_returns_composed_hiragana
    assert_equal("が", Moji.kata_to_hira(NFD_GA, nfc: true)) # 合成済みの「が」
    assert_equal("が", Moji.kata_to_hira(NFD_GA)) # 既定は NFD のまま(従来挙動)
  end

  # 入力の「が」は NFD(か + 結合濁点)。入口の NFC で合成されてから変換される。
  def test_hira_to_kata_with_nfc_returns_composed_katakana
    assert_equal("ガ", Moji.hira_to_kata("が", nfc: true))
  end

  # ---- NFC 自体の副作用(README の既知の制限に対応) ----

  def test_nfc_replaces_cjk_compatibility_ideographs_with_canonical_forms
    # NFC の singleton 分解により CJK 互換漢字は標準字体へ置換される
    # (U+FA19 の神 -> U+795E の神。Windows-31J の IBM 拡張に 20 字が該当)。
    assert_equal("神", Moji.han_to_zen("神", nfc: true))
    assert_equal("神", Moji.han_to_zen("神")) # 既定は無変換
  end

  def test_nfc_with_non_utf8_input_can_raise_when_composed_form_is_unencodable
    # Å(U+212B) は NFC で U+00C5 に合成され Windows-31J へ戻せないため、
    # 既定経路では成功する非 UTF-8 入力の変換が nfc: true では例外になる。
    input = "Å".encode(Encoding::Windows_31J)
    assert_equal(input, Moji.zen_to_han(input))
    assert_raises(Encoding::UndefinedConversionError) { Moji.zen_to_han(input, nfc: true) }
  end

  def test_nfc_disables_case_conversion_of_decomposed_latin_letters
    # 入口の NFC が e + 結合アクセントを é(U+00E9) に合成し tr の a-z 範囲を
    # 外れるため、大文字化されなくなる(既定経路は基底文字だけを大文字化する)。
    assert_equal("É", Moji.upcase("é"))
    assert_equal("é", Moji.upcase("é", nfc: true))
  end

  def test_normalize_zen_han_with_nfc_does_not_converge_wo_with_voiced_mark
    # ｦﾞ(U+FF66 U+FF9E) は本家由来のフォールバックで「ヲ + 非結合の濁点記号
    # U+309B」になり NFC の合成対象外。一方 ｦ + 結合濁点(U+3099) は ヺ に合成
    # される(本家挙動の逆転が nfc: true でも残る)。
    assert_equal("ヲ゛", Moji.normalize_zen_han("ｦﾞ", nfc: true))
    assert_equal("ヺ", Moji.normalize_zen_han("ｦ゙", nfc: true))
  end

  # ---- オブジェクト同一性と非 UTF-8 入力 ----

  def test_nfc_true_always_returns_a_new_string
    # unicode_normalize は正規化不要な入力にも新しい String を返すため、
    # nfc: true では引数そのものが返ることはない(既定経路の assert_same は
    # test_zen_to_han.rb 側で従来どおり固定している)。
    input = "한"
    refute_same(input, Moji.zen_to_han(input, nfc: true))
  end

  def test_nfc_with_non_utf8_input_round_trips_encoding
    input = "ガ".encode(Encoding::Windows_31J) # 合成済み「ガ」の CP932 表現
    result = Moji.zen_to_han(input, nfc: true)
    assert_equal(Encoding::Windows_31J, result.encoding)
    assert_equal("ｶﾞ", result.encode(Encoding::UTF_8))
  end

  def test_nfc_with_invalid_byte_sequence_raises_argument_error
    # 不正バイト列は unicode_normalize が ArgumentError を投げる。既定経路の
    # type と同じ例外クラスで、発生位置が入口に早まるだけ(挙動互換)。
    assert_raises(ArgumentError) { Moji.type("あ\xff", nfc: true) }
    assert_raises(ArgumentError) { Moji.type("あ\xff") }
  end

  def test_nfc_raises_argument_error_where_default_path_passes_through
    # 変換対象の文字種を含まない呼び出しは既定では不正バイト列を素通しするが、
    # nfc: true は入口で無条件に正規化するため ArgumentError になる
    # (README の既知の制限 (6) の固定)。
    bad = "\xff".dup.force_encoding(Encoding::UTF_8)
    assert_same(bad, Moji.zen_to_han(bad, Moji::HAN))
    assert_raises(ArgumentError) { Moji.zen_to_han(bad, Moji::HAN, nfc: true) }
  end

  # ---- 合成先が本家の判定・変換範囲外になる組(README の既知の制限 (5)) ----

  def test_nfc_composition_can_move_kana_out_of_conversion_ranges
    # ウ + 結合濁点は入口の NFC で ヴ(U+30F4) に合成され、tr の ァ-ン 範囲を
    # 外れてカタカナのまま残る(既定は基底文字 ウ だけがひらがな化される)。
    assert_equal("ゔ", Moji.kata_to_hira("ヴ"))
    assert_equal("ヴ", Moji.kata_to_hira("ヴ", nfc: true))
    # ワ + 結合濁点の合成先 ヷ(U+30F7) は ZEN_KATA 範囲外で、zen_to_han は
    # 半角化せず、type の判定も既定の ZEN_KATA から nil へ変わる。
    assert_equal("ヷ", Moji.zen_to_han("ヷ", nfc: true))
    assert_equal(Moji::ZEN_KATA, Moji.type("ヷ"))
    assert_nil(Moji.type("ヷ", nfc: true))
  end

  # ---- 出口 NFC と convert_encoding の経路 ----

  def test_han_to_zen_with_nfc_composes_intermediate_combining_mark
    # 半角カナ + 結合濁点はカナ用正規表現(半角濁点 U+FF9E/FF9F しか拾わない)を
    # 素通りして「全角カナ + U+3099」という中間列になり、出口の NFC が合成する
    # (Detail.convert_encoding の出口適用が省略できない根拠の固定)。
    result = Moji.han_to_zen(HAN_KA_COMBINING, nfc: true)
    assert_equal("ガ", result, codepoints(result)) # 合成済みの「ガ」
  end

  def test_type_with_nfc_and_non_utf8_input_returns_flags
    # 非 UTF-8 入力 × nfc: true × 文字列でない結果、という組で
    # convert_encoding が結果を正規化・encode せず返す経路を通す。
    input = "ガ".encode(Encoding::Windows_31J) # 合成済み「ガ」の CP932 表現
    assert_equal(Moji::ZEN_KATA, Moji.type(input, nfc: true))
    assert_equal(true, Moji.type?(input, Moji::ZEN_KATA, nfc: true))
  end

  # ---- nfc: キーワードの契約 ----

  # README の「文字列を受ける全関数で利用可」という主張を機械検証する。
  # 文字列を受ける公開関数を追加したら、この一覧にも追加すること。
  STRING_FUNCTIONS = %i[
    type type? zen_to_han han_to_zen normalize_zen_han
    upcase downcase kata_to_hira hira_to_kata
  ].freeze

  def test_all_string_functions_accept_nfc_keyword
    STRING_FUNCTIONS.each do |name|
      assert_includes(Moji.method(name).parameters, %i[key nfc], "Moji.#{name}")
    end
  end
end
