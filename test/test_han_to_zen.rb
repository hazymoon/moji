# frozen_string_literal: true

require "test_helper"

# Moji.han_to_zen / Moji.normalize_zen_han のゴールデンテスト。
# 期待値はすべて現行実装（本家 1.6 相当）の実行結果を固定したもの。
class TestHanToZen < Minitest::Test
  # lib 側の Detail テーブルは private 実装なので参照せず、同じ内容をリテラルで持つ。
  # ASCII 記号表は " \ ` #$ を含むためシングルクォートで書く（ダブルクォートだと
  # エスケープ誤りで黙って短くなり、1:1 ループが少ない文字数のまま緑になる）。
  HAN_ASYMBOLS = ' !"#$%&\'()*+,-./:;<=>?@[\]^_`{|}~'
  ZEN_ASYMBOLS = "　！”＃＄％＆’（）＊＋，－．／：；＜＝＞？＠［￥］＾＿‘｛｜｝￣"

  # 半角 JIS 記号の並びは「。「」、ー゛゜・」と対応する。ｰ（長音）はカナ表ではなくこちらにある。
  HAN_JSYMBOLS = "｡｢｣､ｰﾞﾟ･"
  ZEN_JSYMBOLS = "。「」、ー゛゜・"

  HAN_KATAS = "ﾊﾋﾌﾍﾎｳｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄｱｲｴｵﾅﾆﾇﾈﾉﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝｧｨｩｪｫｬｭｮｯ"
  ZEN_KATAS_SEION = "ハヒフヘホウカキクケコサシスセソタチツテトアイエオ" \
                    "ナニヌネノマミムメモヤユヨラリルレロワヲンァィゥェォャュョッ"
  ZEN_KATAS_DAKUON = "バビブベボヴガギグゲゴザジズゼゾダヂヅデド"
  ZEN_KATAS_HANDAKUON = "パピプペポ"

  # 表そのものが壊れていないことを先に固定する（自己防衛）。
  def test_embedded_tables_have_expected_lengths
    assert_equal(33, HAN_ASYMBOLS.length)
    assert_equal(33, ZEN_ASYMBOLS.length)
    assert_equal(8, HAN_JSYMBOLS.length)
    assert_equal(8, ZEN_JSYMBOLS.length)
    assert_equal(55, HAN_KATAS.length)
    assert_equal(55, ZEN_KATAS_SEION.length)
    assert_equal(21, ZEN_KATAS_DAKUON.length)
    assert_equal(5, ZEN_KATAS_HANDAKUON.length)
  end

  # ---------------------------------------------------------------- デフォルト（ALL）

  def test_han_to_zen_default_converts_ascii_and_kana
    assert_equal("Ｒｕｂｙ！？", Moji.han_to_zen("Ruby!?"))
    assert_equal("ｍｏｊｉ　１．６　テスト", Moji.han_to_zen("moji 1.6 ﾃｽﾄ"))
    assert_equal(
      "ドラえもん（Ｄｏｒａｅｍｏｎ）は、日本で１番有名な漫画だ。",
      Moji.han_to_zen("ﾄﾞﾗえもん(Doraemon)は､日本で1番有名な漫画だ｡")
    )
  end

  def test_han_to_zen_default_covers_every_han_category_at_once
    src = "abcXYZ012 !\"\#$%&*+,-./:;<=>?@[\\]^_`{|}~ ｱｶﾞ ｡｢｣､･ｰﾞﾟ"
    assert_equal(
      "ａｂｃＸＹＺ０１２　！”＃＄％＆＊＋，－．／：；＜＝＞？＠［￥］＾＿‘｛｜｝￣　アガ　。「」、・ー゛゜",
      Moji.han_to_zen(src)
    )
  end

  def test_han_to_zen_leaves_hiragana_kanji_and_zenkaku_untouched
    assert_equal("ひらがな漢字", Moji.han_to_zen("ひらがな漢字"))
    assert_equal("Ｒｕｂｙ", Moji.han_to_zen("Ｒｕｂｙ"))
    assert_equal("ガパヴ", Moji.han_to_zen("ガパヴ"))
  end

  def test_han_to_zen_empty_string
    assert_equal("", Moji.han_to_zen(""))
  end

  def test_han_to_zen_accepts_frozen_string
    assert_equal("ａｂｃ　ア", Moji.han_to_zen("abc ｱ"))
  end

  # ---------------------------------------------------------------- 半角カナ → 全角カナ

  def test_han_to_zen_seion_for_every_han_kata
    HAN_KATAS.each_char.with_index do |han, i|
      assert_equal(ZEN_KATAS_SEION[i], Moji.han_to_zen(han), "seion mismatch at index #{i} (#{han})")
    end
  end

  # 濁音表は先頭 21 文字ぶんしかない。対応が無い文字（ｱ 以降）は
  # 清音 + 全角濁点「゛」になる（半角ﾞが JSYMBOL 変換で全角化されるため）。
  def test_han_to_zen_dakuten_for_every_han_kata
    HAN_KATAS.each_char.with_index do |han, i|
      expected = i < ZEN_KATAS_DAKUON.length ? ZEN_KATAS_DAKUON[i] : "#{ZEN_KATAS_SEION[i]}゛"
      assert_equal(expected, Moji.han_to_zen("#{han}ﾞ"), "dakuten mismatch at index #{i} (#{han})")
    end
  end

  # 半濁音表は先頭 5 文字（ﾊﾋﾌﾍﾎ）ぶんのみ。それ以外は清音 + 全角半濁点「゜」。
  def test_han_to_zen_handakuten_for_every_han_kata
    HAN_KATAS.each_char.with_index do |han, i|
      expected = i < ZEN_KATAS_HANDAKUON.length ? ZEN_KATAS_HANDAKUON[i] : "#{ZEN_KATAS_SEION[i]}゜"
      assert_equal(expected, Moji.han_to_zen("#{han}ﾟ"), "handakuten mismatch at index #{i} (#{han})")
    end
  end

  def test_han_to_zen_representative_voiced_kana
    assert_equal("ガ", Moji.han_to_zen("ｶﾞ"))
    assert_equal("ヴ", Moji.han_to_zen("ｳﾞ"))
    assert_equal("パ", Moji.han_to_zen("ﾊﾟ"))
    assert_equal("ニホンゴ", Moji.han_to_zen("ﾆﾎﾝｺﾞ"))
    assert_equal("パソコン", Moji.han_to_zen("ﾊﾟｿｺﾝ"))
  end

  # 濁点・半濁点が付けない文字に ﾞ/ﾟ を付けても脱落せず、全角の記号として残る。
  def test_han_to_zen_invalid_voiced_combinations_keep_the_mark
    assert_equal("ア゛", Moji.han_to_zen("ｱﾞ"))
    assert_equal("マ゜", Moji.han_to_zen("ﾏﾟ"))
    assert_equal("ワ゛", Moji.han_to_zen("ﾜﾞ"))
    assert_equal("ヲ゛", Moji.han_to_zen("ｦﾞ"))
    assert_equal("ン゛", Moji.han_to_zen("ﾝﾞ"))
    assert_equal("ッ゛", Moji.han_to_zen("ｯﾞ"))
    assert_equal("ャ゛", Moji.han_to_zen("ｬﾞ"))
    assert_equal("ウ゜", Moji.han_to_zen("ｳﾟ"))
  end

  def test_han_to_zen_standalone_voiced_marks
    assert_equal("゛", Moji.han_to_zen("ﾞ"))
    assert_equal("゜", Moji.han_to_zen("ﾟ"))
    assert_equal("゛゜", Moji.han_to_zen("ﾞﾟ"))
    assert_equal("゜カ", Moji.han_to_zen("ﾟｶ"))
  end

  # gsub は「カナ + 記号 0〜1 個」で貪欲に食うので、余った記号は独立した全角記号になる。
  def test_han_to_zen_consecutive_voiced_marks
    assert_equal("ガ゛", Moji.han_to_zen("ｶﾞﾞ"))
    assert_equal("゛ガ", Moji.han_to_zen("ﾞｶﾞ"))
    assert_equal("カ゜゛", Moji.han_to_zen("ｶﾟﾞ"))
    assert_equal("パ゜", Moji.han_to_zen("ﾊﾟﾟ"))
    assert_equal("ガカ゜", Moji.han_to_zen("ｶﾞｶﾟ"))
    assert_equal("ヴヴ", Moji.han_to_zen("ｳﾞｳﾞ"))
    assert_equal("アイヴエ", Moji.han_to_zen("ｱｲｳﾞｴ"))
  end

  def test_han_to_zen_prolonged_sound_mark
    # ｰ（半角長音）は半角カナ表ではなく半角 JIS 記号側にある。
    assert_equal("ー", Moji.han_to_zen("ｰ"))
    assert_equal("ルビー", Moji.han_to_zen("ﾙﾋﾞｰ"))
  end

  # ---------------------------------------------------------------- 記号表の 1:1 対応

  def test_han_to_zen_maps_every_han_asymbol_one_to_one
    HAN_ASYMBOLS.each_char.with_index do |han, i|
      assert_equal(ZEN_ASYMBOLS[i], Moji.han_to_zen(han), "asymbol mismatch at index #{i} (#{han})")
    end
  end

  def test_han_to_zen_asymbol_notable_pairs
    # 半角スペース→全角スペース、\→￥、~→￣、'→’、`→‘。
    assert_equal("　", Moji.han_to_zen(" "))
    assert_equal("￥", Moji.han_to_zen("\\"))
    assert_equal("￣", Moji.han_to_zen("~"))
    assert_equal("’", Moji.han_to_zen("'"))
    assert_equal("‘", Moji.han_to_zen("`"))
    assert_equal("”", Moji.han_to_zen("\""))
    assert_equal("－", Moji.han_to_zen("-"))
    assert_equal("［￥］", Moji.han_to_zen("[\\]"))
  end

  def test_han_to_zen_maps_every_han_jsymbol_one_to_one
    HAN_JSYMBOLS.each_char.with_index do |han, i|
      assert_equal(ZEN_JSYMBOLS[i], Moji.han_to_zen(han), "jsymbol mismatch at index #{i} (#{han})")
    end
  end

  # ---------------------------------------------------------------- type スコープ

  SCOPE_SOURCE = "abcXYZ012 !\"\#$%&*+,-./:;<=>?@[\\]^_`{|}~ ｱｶﾞ ｡｢｣､･ｰﾞﾟ"

  def test_han_to_zen_scope_han_lower
    assert_equal(
      "ａｂｃXYZ012 !\"\#$%&*+,-./:;<=>?@[\\]^_`{|}~ ｱｶﾞ ｡｢｣､･ｰﾞﾟ",
      Moji.han_to_zen(SCOPE_SOURCE, Moji::HAN_LOWER)
    )
  end

  def test_han_to_zen_scope_han_upper
    assert_equal(
      "abcＸＹＺ012 !\"\#$%&*+,-./:;<=>?@[\\]^_`{|}~ ｱｶﾞ ｡｢｣､･ｰﾞﾟ",
      Moji.han_to_zen(SCOPE_SOURCE, Moji::HAN_UPPER)
    )
  end

  def test_han_to_zen_scope_han_number
    assert_equal(
      "abcXYZ０１２ !\"\#$%&*+,-./:;<=>?@[\\]^_`{|}~ ｱｶﾞ ｡｢｣､･ｰﾞﾟ",
      Moji.han_to_zen(SCOPE_SOURCE, Moji::HAN_NUMBER)
    )
  end

  def test_han_to_zen_scope_han_asymbol
    assert_equal(
      "abcXYZ012　！”＃＄％＆＊＋，－．／：；＜＝＞？＠［￥］＾＿‘｛｜｝￣　ｱｶﾞ　｡｢｣､･ｰﾞﾟ",
      Moji.han_to_zen(SCOPE_SOURCE, Moji::HAN_ASYMBOL)
    )
  end

  # HAN_KATA を含まず HAN_JSYMBOL だけを含む場合、ﾞ ﾟ は全角記号へ独立変換され、
  # 直前の半角カナは半角のまま残る（ｶﾞ → ｶ゛）。
  def test_han_to_zen_scope_han_jsymbol
    assert_equal(
      "abcXYZ012 !\"\#$%&*+,-./:;<=>?@[\\]^_`{|}~ ｱｶ゛ 。「」、・ー゛゜",
      Moji.han_to_zen(SCOPE_SOURCE, Moji::HAN_JSYMBOL)
    )
  end

  def test_han_to_zen_scope_han_kata
    assert_equal(
      "abcXYZ012 !\"\#$%&*+,-./:;<=>?@[\\]^_`{|}~ アガ ｡｢｣､･ｰﾞﾟ",
      Moji.han_to_zen(SCOPE_SOURCE, Moji::HAN_KATA)
    )
  end

  def test_han_to_zen_scope_composites
    assert_equal(
      "ａｂｃＸＹＺ０１２ !\"\#$%&*+,-./:;<=>?@[\\]^_`{|}~ ｱｶﾞ ｡｢｣､･ｰﾞﾟ",
      Moji.han_to_zen(SCOPE_SOURCE, Moji::HAN_ALNUM)
    )
    assert_equal(
      "abcXYZ012　！”＃＄％＆＊＋，－．／：；＜＝＞？＠［￥］＾＿‘｛｜｝￣　ｱｶ゛　。「」、・ー゛゜",
      Moji.han_to_zen(SCOPE_SOURCE, Moji::HAN_SYMBOL)
    )
    expected_all = "ａｂｃＸＹＺ０１２　！”＃＄％＆＊＋，－．／：；＜＝＞？＠［￥］＾＿‘｛｜｝￣　アガ　。「」、・ー゛゜"
    assert_equal(expected_all, Moji.han_to_zen(SCOPE_SOURCE, Moji::HAN))
    assert_equal(expected_all, Moji.han_to_zen(SCOPE_SOURCE, Moji::ALL))
  end

  # HAN_KATA と HAN_JSYMBOL の同時指定は、カナ変換が先に走るぶん ALL と同じ結果になる。
  def test_han_to_zen_scope_kata_and_jsymbol_combination
    src = "ｱﾞｶﾞﾊﾟｳﾞﾞﾟ･ｰ｡｢｣､"
    assert_equal("アﾞガパヴﾞﾟ･ｰ｡｢｣､", Moji.han_to_zen(src, Moji::HAN_KATA))
    assert_equal("ｱ゛ｶ゛ﾊ゜ｳ゛゛゜・ー。「」、", Moji.han_to_zen(src, Moji::HAN_JSYMBOL))
    assert_equal("ア゛ガパヴ゛゜・ー。「」、", Moji.han_to_zen(src, Moji::HAN_KATA | Moji::HAN_JSYMBOL))
    assert_equal("ア゛ガパヴ゛゜・ー。「」、", Moji.han_to_zen(src, Moji::ALL))
  end

  # HAN_KATA だけを指定すると、対応する全角が無い組み合わせの記号は半角のまま残る。
  def test_han_to_zen_han_kata_scope_keeps_half_width_marks
    assert_equal("アﾞ", Moji.han_to_zen("ｱﾞ", Moji::HAN_KATA))
    assert_equal("マﾟ", Moji.han_to_zen("ﾏﾟ", Moji::HAN_KATA))
    assert_equal("ガﾞ", Moji.han_to_zen("ｶﾞﾞ", Moji::HAN_KATA))
    assert_equal("ヴ", Moji.han_to_zen("ｳﾞ", Moji::HAN_KATA))
  end

  def test_han_to_zen_symbol_scope_leaves_alnum
    assert_equal("Ruby！？", Moji.han_to_zen("Ruby!?", Moji::SYMBOL))
  end

  # ZEN_* 系のフラグを han_to_zen に渡しても対応する半角側の分岐が立たず無変換。
  def test_han_to_zen_with_zen_scope_is_noop
    assert_equal("ｱ", Moji.han_to_zen("ｱ", Moji::ZEN_KATA))
    assert_equal("ﾃｽﾄ", Moji.han_to_zen("ﾃｽﾄ", Moji::ZEN))
  end

  # HAN_CONTROL はどの変換表にも結び付いていないので文字列は素通しになる。
  def test_han_to_zen_with_han_control_scope_is_noop
    assert_equal("ﾃｽﾄ", Moji.han_to_zen("ﾃｽﾄ", Moji::HAN_CONTROL))
  end

  # KATA / KANA は HAN_KATA を含むのでカナだけ変換される。
  def test_han_to_zen_with_kata_and_kana_scope
    assert_equal("ア", Moji.han_to_zen("ｱ", Moji::KATA))
    assert_equal("ア", Moji.han_to_zen("ｱ", Moji::KANA))
  end

  # ---------------------------------------------------------------- 往復

  # 入力が半角のみなら han_to_zen → zen_to_han は恒等になる。
  def test_roundtrip_is_identity_for_half_width_only_input
    inputs = [
      "Ruby!?", "abc XYZ 012", HAN_ASYMBOLS, HAN_JSYMBOLS,
      "ｱｲｳｴｵ", "ｶﾞｷﾞｸﾞ", "ﾊﾟﾋﾟﾌﾟ", "ｳﾞ", "ｱﾞ", "ﾏﾟ", "ﾞ", "ﾟ", "ｰ",
      "ﾆﾎﾝｺﾞ", "", "ｶﾞﾞ", "ﾞｶﾞ", "ｶﾟﾞ", "ﾜﾞｦﾞ",
    ]
    inputs.each do |src|
      assert_equal(src, Moji.zen_to_han(Moji.han_to_zen(src)), "roundtrip broke for #{src.inspect}")
    end
  end

  # 入力に全角が含まれると zen_to_han が「元から全角だった文字」も半角に落とすため恒等にならない。
  def test_roundtrip_is_not_identity_when_input_contains_full_width
    {
      "Ａ" => "A",
      "Ｒｕｂｙ" => "Ruby",
      "！" => "!",
      "　" => " ",
      "。" => "｡",
      "ガ" => "ｶﾞ",
      "ヴ" => "ｳﾞ",
      "ー" => "ｰ",
      "゛" => "ﾞ",
      "ｱア" => "ｱｱ",
      "ﾃｽﾄＴＥＳＴ" => "ﾃｽﾄTEST",
      "ドラえもん" => "ﾄﾞﾗえもん",
    }.each do |src, expected|
      assert_equal(expected, Moji.zen_to_han(Moji.han_to_zen(src)), "roundtrip mismatch for #{src.inspect}")
      refute_equal(src, Moji.zen_to_han(Moji.han_to_zen(src)))
    end
  end

  # ひらがな・漢字はどちらの変換対象でもないので往復しても不変（全角カナは対象なので不変ではない）。
  def test_roundtrip_is_identity_for_hiragana_and_kanji
    %w[ひらがな 漢字 日本語の文字種].each do |src|
      assert_equal(src, Moji.zen_to_han(Moji.han_to_zen(src)))
    end
  end

  # 逆向き（zen_to_han → han_to_zen）は、分解済みの「ウ゛」が「ヴ」へ合成されて恒等にならない。
  def test_reverse_roundtrip_composes_decomposed_voiced_kana
    assert_equal("ヴ", Moji.han_to_zen(Moji.zen_to_han("ウ゛")))
    assert_equal("ガ", Moji.han_to_zen(Moji.zen_to_han("カ゛")))
    assert_equal("パ", Moji.han_to_zen(Moji.zen_to_han("ハ゜")))
    # 合成先が無い組み合わせは分解されたまま戻る。
    assert_equal("ワ゛", Moji.han_to_zen(Moji.zen_to_han("ワ゛")))
    assert_equal("ヲ゛", Moji.han_to_zen(Moji.zen_to_han("ヲ゛")))
  end

  # ---------------------------------------------------------------- エンコーディング

  def test_han_to_zen_preserves_input_encoding
    src = "ﾃｽﾄ Ruby".encode("Windows-31J")
    result = Moji.han_to_zen(src)
    assert_equal(Encoding::Windows_31J, result.encoding)
    assert_equal("テスト　Ｒｕｂｙ", result.encode(Encoding::UTF_8))
  end

  # 入力が US-ASCII だと、変換結果を元エンコーディングへ戻す段で必ず失敗する。
  def test_han_to_zen_raises_when_us_ascii_input_produces_non_ascii
    src = "abc".encode(Encoding::US_ASCII)
    assert_raises(Encoding::UndefinedConversionError) { Moji.han_to_zen(src) }
    # 変換対象が無ければ結果は ASCII のままなので例外にならない。
    assert_equal("abc", Moji.han_to_zen(src, Moji::HAN_KATA))
  end

  def test_han_to_zen_with_default_internal_utf8
    with_default_internal(Encoding::UTF_8) do
      assert_equal("ガ", Moji.han_to_zen("ｶﾞ"))
      assert_equal("Ｒｕｂｙ", Moji.han_to_zen("Ruby"))
    end
  end

  # Encoding.default_internal が UTF-8 以外だと han_kata が
  # その内部エンコーディングの正規表現を返し、UTF-8 のソースリテラルへ
  # 補間する時点で衝突して RegexpError になる（HAN_KATA を含むスコープのみ）。
  def test_han_to_zen_raises_regexp_error_when_default_internal_is_not_utf8
    with_default_internal(Encoding::Windows_31J) do
      assert_raises(RegexpError) { Moji.han_to_zen("ｶﾞ") }
      assert_raises(RegexpError) { Moji.normalize_zen_han("ｶﾞ") }
      # HAN_KATA を含まないスコープなら動的正規表現を組まないので通る。
      assert_equal("ｶ゛", Moji.han_to_zen("ｶﾞ", Moji::HAN_JSYMBOL))
    end
  end

  # ---------------------------------------------------------------- normalize_zen_han

  def test_normalize_zen_han_mixed_examples
    assert_equal("Ruby ルビー 2026!", Moji.normalize_zen_han("Ｒｕｂｙ ﾙﾋﾞｰ ２０２６！"))
    assert_equal("Abc123アイウ", Moji.normalize_zen_han("Ａｂｃ１２３ｱｲｳ"))
    assert_equal("Moji 1.6", Moji.normalize_zen_han("Ｍｏｊｉ　１．６"))
    assert_equal("ニホン ゴ", Moji.normalize_zen_han("ﾆﾎﾝ ｺﾞ"))
    assert_equal("テスト-テスト", Moji.normalize_zen_han("ﾃｽﾄ－ﾃｽﾄ"))
  end

  # ASCII 英数記号は半角へ。
  def test_normalize_zen_han_moves_ascii_alnum_and_symbols_to_han
    assert_equal("Ruby", Moji.normalize_zen_han("Ｒｕｂｙ"))
    assert_equal("ruby", Moji.normalize_zen_han("ｒｕｂｙ"))
    assert_equal("012", Moji.normalize_zen_han("０１２"))
    assert_equal("!?\#$%", Moji.normalize_zen_han("！？＃＄％"))
    assert_equal(" ", Moji.normalize_zen_han("　"))
    assert_equal(HAN_ASYMBOLS, Moji.normalize_zen_han(ZEN_ASYMBOLS))
  end

  # JIS 記号・半角カナは全角へ。
  def test_normalize_zen_han_moves_jsymbol_and_han_kata_to_zen
    assert_equal("パソコン", Moji.normalize_zen_han("ﾊﾟｿｺﾝ"))
    assert_equal("ガギグ", Moji.normalize_zen_han("ｶﾞｷﾞｸﾞ"))
    assert_equal("ヴ", Moji.normalize_zen_han("ｳﾞ"))
    assert_equal("ア゛", Moji.normalize_zen_han("ｱﾞ"))
    assert_equal("゛゜", Moji.normalize_zen_han("ﾞﾟ"))
    assert_equal("。「」、・ー", Moji.normalize_zen_han("｡｢｣､･ｰ"))
    assert_equal(ZEN_JSYMBOLS, Moji.normalize_zen_han(HAN_JSYMBOLS))
  end

  # 全角の JIS 記号は半角へ落とさない（ZEN_JSYMBOL は変換対象外）。
  def test_normalize_zen_han_keeps_zen_jsymbol_as_is
    assert_equal("。「」、・ー", Moji.normalize_zen_han("。「」、・ー"))
    assert_equal("＼", Moji.normalize_zen_han("＼"))
    assert_equal("〜", Moji.normalize_zen_han("〜"))
  end

  def test_normalize_zen_han_keeps_hiragana_kanji_and_zen_kata
    assert_equal("ひらがな", Moji.normalize_zen_han("ひらがな"))
    assert_equal("漢字", Moji.normalize_zen_han("漢字"))
    assert_equal(
      "ドラえもん(Doraemon)は、日本で1番有名な漫画だ。",
      Moji.normalize_zen_han("ドラえもん(Doraemon)は、日本で1番有名な漫画だ。")
    )
  end

  # ZEN_ASYMBOL 表が全角形ブロックではなく約物・互換文字を採っているため、
  # ￥(U+FFE5) と ￣(U+FFE3) は半角へ落ちる一方、＂(U+FF02)・＼(U+FF3C)・～(U+FF5E) は残る。
  def test_normalize_zen_han_asymbol_table_quirks
    assert_equal("\\", Moji.normalize_zen_han("￥"))
    assert_equal("~", Moji.normalize_zen_han("￣"))
    assert_equal("\"", Moji.normalize_zen_han("”"))
    assert_equal("`", Moji.normalize_zen_han("‘"))
    assert_equal("'", Moji.normalize_zen_han("’"))
    assert_equal("＂", Moji.normalize_zen_han("＂"))
    assert_equal("～", Moji.normalize_zen_han("～"))
    assert_equal("!＂#", Moji.normalize_zen_han("！＂＃"))
  end

  def test_normalize_zen_han_leaves_unmapped_characters
    assert_equal("①②", Moji.normalize_zen_han("①②"))
    assert_equal("㈱", Moji.normalize_zen_han("㈱"))
    assert_equal("Ⅰ", Moji.normalize_zen_han("Ⅰ"))
  end

  def test_normalize_zen_han_is_idempotent
    [
      "Ｒｕｂｙ ﾙﾋﾞｰ ２０２６！", "ｱﾞ", "ﾊﾟｿｺﾝ", "￥￣～", "Ｍｏｊｉ　１．６",
      "！＂＃", "｡｢｣､･ｰ", "ドラえもん(Doraemon)は、日本で1番有名な漫画だ。",
    ].each do |src|
      once = Moji.normalize_zen_han(src)
      assert_equal(once, Moji.normalize_zen_han(once), "not idempotent for #{src.inspect}")
    end
  end

  def test_normalize_zen_han_empty_and_frozen
    assert_equal("", Moji.normalize_zen_han(""))
    assert_equal("Ruby", Moji.normalize_zen_han("Ｒｕｂｙ"))
  end

  def test_normalize_zen_han_preserves_input_encoding
    src = "Ｒｕｂｙ ﾙﾋﾞｰ".encode("Windows-31J")
    result = Moji.normalize_zen_han(src)
    assert_equal(Encoding::Windows_31J, result.encoding)
    assert_equal("Ruby ルビー", result.encode(Encoding::UTF_8))
  end

  private

  # グローバル状態は必ず ensure で戻す。
  def with_default_internal(encoding)
    orig_internal = Encoding.default_internal
    orig_verbose = $VERBOSE
    begin
      $VERBOSE = nil
      Encoding.default_internal = encoding
      yield
    ensure
      Encoding.default_internal = orig_internal
      $VERBOSE = orig_verbose
    end
  end
end
