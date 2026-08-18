# frozen_string_literal: true

require "test_helper"

# エンコーディング処理のゴールデンテスト。
#
# 期待値はすべて現行実装（本家 1.6 相当）を実行して得た実測値。直感に反するもの
# （ASCII のみの文字種が US-ASCII 正規表現を返す、漢字・罫線だけ encoding 引数が
# 無視される、Shift_JIS 入力の han_to_zen が例外になる等）も実挙動のまま固定する。
class TestEncoding < Minitest::Test
  include MojiTestHelpers

  # 半角カナ・ひらがな・全角カナ・ASCII 英数・全角記号を含み、
  # Shift_JIS / Windows-31J / EUC-JP のいずれでも表現できる文字列。
  SRC = "ﾄﾞﾗえもんアイウABC123！？"

  # SRC を UTF-8 のまま処理したときの実測値（ゴールデン値）。
  # 非 UTF-8 入力のテストはこのリテラルと突き合わせる（両辺を実装から取らない）。
  ZEN_TO_HAN_RESULT      = "ﾄﾞﾗえもんｱｲｳABC123!?"
  HAN_TO_ZEN_RESULT      = "ドラえもんアイウＡＢＣ１２３！？"
  KATA_TO_HIRA_RESULT    = "ﾄﾞﾗえもんあいうABC123！？"
  NORMALIZE_ZEN_HAN_RESULT = "ドラえもんアイウABC123!?"

  # --------------------------------------------------------------------------
  # UTF-8 のゴールデン値（以降の往復テストの比較基準）
  # --------------------------------------------------------------------------

  def test_utf8_input_returns_golden_values_and_utf8_encoding
    assert_equal ZEN_TO_HAN_RESULT, Moji.zen_to_han(SRC)
    assert_equal HAN_TO_ZEN_RESULT, Moji.han_to_zen(SRC)
    assert_equal KATA_TO_HIRA_RESULT, Moji.kata_to_hira(SRC)
    assert_equal NORMALIZE_ZEN_HAN_RESULT, Moji.normalize_zen_han(SRC)

    assert_equal Encoding::UTF_8, Moji.zen_to_han(SRC).encoding
    assert_equal Encoding::UTF_8, Moji.han_to_zen(SRC).encoding
    assert_equal Encoding::UTF_8, Moji.kata_to_hira(SRC).encoding
    assert_equal Encoding::UTF_8, Moji.normalize_zen_han(SRC).encoding
  end

  # --------------------------------------------------------------------------
  # 非 UTF-8 入力の往復（返値のエンコーディングは入力と同一）
  # --------------------------------------------------------------------------

  def test_shift_jis_input_round_trips_with_same_encoding
    src = SRC.encode(Encoding::Shift_JIS)

    zen_to_han = Moji.zen_to_han(src)
    assert_equal Encoding::Shift_JIS, zen_to_han.encoding
    assert_equal ZEN_TO_HAN_RESULT, zen_to_han.encode(Encoding::UTF_8)

    han_to_zen = Moji.han_to_zen(src)
    assert_equal Encoding::Shift_JIS, han_to_zen.encoding
    assert_equal HAN_TO_ZEN_RESULT, han_to_zen.encode(Encoding::UTF_8)

    kata_to_hira = Moji.kata_to_hira(src)
    assert_equal Encoding::Shift_JIS, kata_to_hira.encoding
    assert_equal KATA_TO_HIRA_RESULT, kata_to_hira.encode(Encoding::UTF_8)

    normalized = Moji.normalize_zen_han(src)
    assert_equal Encoding::Shift_JIS, normalized.encoding
    assert_equal NORMALIZE_ZEN_HAN_RESULT, normalized.encode(Encoding::UTF_8)
  end

  def test_windows_31j_input_round_trips_with_same_encoding
    src = SRC.encode(Encoding::Windows_31J)

    zen_to_han = Moji.zen_to_han(src)
    assert_equal Encoding::Windows_31J, zen_to_han.encoding
    assert_equal ZEN_TO_HAN_RESULT, zen_to_han.encode(Encoding::UTF_8)

    han_to_zen = Moji.han_to_zen(src)
    assert_equal Encoding::Windows_31J, han_to_zen.encoding
    assert_equal HAN_TO_ZEN_RESULT, han_to_zen.encode(Encoding::UTF_8)

    kata_to_hira = Moji.kata_to_hira(src)
    assert_equal Encoding::Windows_31J, kata_to_hira.encoding
    assert_equal KATA_TO_HIRA_RESULT, kata_to_hira.encode(Encoding::UTF_8)

    normalized = Moji.normalize_zen_han(src)
    assert_equal Encoding::Windows_31J, normalized.encoding
    assert_equal NORMALIZE_ZEN_HAN_RESULT, normalized.encode(Encoding::UTF_8)
  end

  def test_euc_jp_input_round_trips_with_same_encoding
    src = SRC.encode(Encoding::EUC_JP)

    zen_to_han = Moji.zen_to_han(src)
    assert_equal Encoding::EUC_JP, zen_to_han.encoding
    assert_equal ZEN_TO_HAN_RESULT, zen_to_han.encode(Encoding::UTF_8)

    han_to_zen = Moji.han_to_zen(src)
    assert_equal Encoding::EUC_JP, han_to_zen.encoding
    assert_equal HAN_TO_ZEN_RESULT, han_to_zen.encode(Encoding::UTF_8)

    kata_to_hira = Moji.kata_to_hira(src)
    assert_equal Encoding::EUC_JP, kata_to_hira.encoding
    assert_equal KATA_TO_HIRA_RESULT, kata_to_hira.encode(Encoding::UTF_8)

    normalized = Moji.normalize_zen_han(src)
    assert_equal Encoding::EUC_JP, normalized.encoding
    assert_equal NORMALIZE_ZEN_HAN_RESULT, normalized.encode(Encoding::UTF_8)
  end

  def test_empty_non_utf8_string_keeps_its_encoding
    assert_equal Encoding::EUC_JP, Moji.zen_to_han("".encode(Encoding::EUC_JP)).encoding
    assert_equal Encoding::Shift_JIS, Moji.han_to_zen("".encode(Encoding::Shift_JIS)).encoding
  end

  # --------------------------------------------------------------------------
  # Moji.type / Moji.type? に非 UTF-8 文字列を渡す
  # 返値はフラグ（String でない）ので元エンコーディングへの復元は行われない
  # --------------------------------------------------------------------------

  def test_type_with_shift_jis_string_returns_same_flag_as_utf8
    {
      "漢" => Moji::ZEN_KANJI,
      "ｱ" => Moji::HAN_KATA,
      "ア" => Moji::ZEN_KATA,
      "あ" => Moji::ZEN_HIRA,
      "Ａ" => Moji::ZEN_UPPER,
      "a" => Moji::HAN_LOWER,
      "1" => Moji::HAN_NUMBER,
      "！" => Moji::ZEN_ASYMBOL,
      "!" => Moji::HAN_ASYMBOL,
      "\n" => Moji::HAN_CONTROL,
      "α" => Moji::ZEN_GREEK,
      "А" => Moji::ZEN_CYRILLIC,
      # ■ は罫線ではなく ZEN_JSYMBOL 扱い（CHAR_REGEXPS の走査順による）
      "■" => Moji::ZEN_JSYMBOL,
    }.each do |ch, expected|
      assert_equal expected, Moji.type(ch), "UTF-8: #{ch.inspect}"
      assert_equal expected, Moji.type(ch.encode(Encoding::Windows_31J)), "SJIS: #{ch.inspect}"
      assert_equal expected, Moji.type(ch.encode(Encoding::EUC_JP)), "EUC: #{ch.inspect}"
    end
  end

  def test_type_with_empty_non_utf8_string_returns_nil
    assert_nil Moji.type("".encode(Encoding::Windows_31J))
    assert_nil Moji.type("".encode(Encoding::EUC_JP))
  end

  def test_type_p_with_non_utf8_string
    assert Moji.type?("Ａ".encode(Encoding::Windows_31J), Moji::ZEN)
    refute Moji.type?("A".encode(Encoding::Windows_31J), Moji::ZEN)
    assert Moji.type?("ｱ".encode(Encoding::EUC_JP), Moji::KATA)
    assert Moji.type?("あ".encode(Encoding::Shift_JIS), Moji::KANA)
  end

  # ASCII-8BIT（バイナリ）は UTF-8 へ変換できず例外になる
  def test_type_with_binary_string_raises_undefined_conversion_error
    error = assert_raises(Encoding::UndefinedConversionError) { Moji.type("漢".b) }
    assert_equal "\"\\xE6\" from ASCII-8BIT to UTF-8", error.message
  end

  # --------------------------------------------------------------------------
  # Moji.regexp に encoding を渡す
  # --------------------------------------------------------------------------

  def test_regexp_with_encoding_returns_regexp_of_that_encoding
    {
      Encoding::Shift_JIS => Encoding::Shift_JIS,
      Encoding::Windows_31J => Encoding::Windows_31J,
      Encoding::EUC_JP => Encoding::EUC_JP,
      Encoding::UTF_8 => Encoding::UTF_8,
    }.each do |arg, expected|
      regexp = Moji.regexp(Moji::HIRA, arg)
      assert_equal expected, regexp.encoding, "arg=#{arg}"
      assert regexp.fixed_encoding?, "arg=#{arg}"
    end
  end

  # Encoding::SJIS は Windows-31J の別名なので、返る正規表現も Windows-31J になる
  def test_encoding_sjis_is_alias_of_windows_31j
    assert_equal Encoding::Windows_31J, Encoding::SJIS
    assert_equal Encoding::Windows_31J, Moji.regexp(Moji::HIRA, Encoding::SJIS).encoding
  end

  def test_regexp_with_encoding_matches_string_of_same_encoding
    regexp = Moji.regexp(Moji::HIRA, Encoding::SJIS)
    assert_equal 0, regexp =~ "あ".encode(Encoding::Windows_31J)
    assert_nil regexp =~ "ア".encode(Encoding::Windows_31J)

    euc = Moji.regexp(Moji::ZEN_KATA, Encoding::EUC_JP)
    assert_equal 0, euc =~ "ア".encode(Encoding::EUC_JP)
    assert_nil euc =~ "あ".encode(Encoding::EUC_JP)
  end

  # 非 ASCII の正規表現は fixed_encoding? なので、別エンコーディングの文字列とは照合できない
  def test_regexp_with_encoding_raises_against_utf8_string
    regexp = Moji.regexp(Moji::HIRA, Encoding::SJIS)
    error = assert_raises(Encoding::CompatibilityError) { regexp =~ "あ" }
    assert_equal(
      "incompatible encoding regexp match (Windows-31J regexp with UTF-8 string)",
      error.message
    )
  end

  # ASCII のみで書かれた文字種は encoding 引数によらず US-ASCII の正規表現になり、
  # US-ASCII は ASCII 互換なのでどのエンコーディングの文字列とも照合できる
  def test_regexp_of_ascii_only_types_is_us_ascii_regardless_of_encoding
    [Moji::HAN_CONTROL, Moji::HAN_ASYMBOL, Moji::HAN_NUMBER,
     Moji::HAN_UPPER, Moji::HAN_LOWER,].each do |type|
      [nil, Encoding::Shift_JIS, Encoding::Windows_31J,
       Encoding::EUC_JP, Encoding::UTF_8,].each do |encoding|
        regexp = encoding ? Moji.regexp(type, encoding) : Moji.regexp(type)
        assert_equal Encoding::US_ASCII, regexp.encoding, "type=#{type} enc=#{encoding}"
        refute regexp.fixed_encoding?, "type=#{type} enc=#{encoding}"
      end
    end

    regexp = Moji.regexp(Moji::HAN_NUMBER, Encoding::SJIS)
    assert_equal 0, regexp =~ "1".encode(Encoding::Windows_31J)
    assert_equal 0, regexp =~ "1"
    assert_equal 0, regexp =~ "1".encode(Encoding::EUC_JP)
  end

  # ZEN_KANJI / ZEN_LINE の正規表現は \uXXXX エスケープ（ASCII 文字列）で書かれているため、
  # encode しても中身が変わらず、Ruby が \u を見て UTF-8 の正規表現に戻す。
  # 結果として encoding 引数が効かず、SJIS 文字列との照合は例外になる。
  def test_regexp_of_kanji_and_line_ignores_encoding_argument
    [Moji::ZEN_KANJI, Moji::ZEN_LINE].each do |type|
      [Encoding::Shift_JIS, Encoding::Windows_31J, Encoding::EUC_JP].each do |encoding|
        regexp = Moji.regexp(type, encoding)
        assert_equal Encoding::UTF_8, regexp.encoding, "type=#{type} enc=#{encoding}"
        assert regexp.fixed_encoding?, "type=#{type} enc=#{encoding}"
      end
    end

    regexp = Moji.regexp(Moji::ZEN_KANJI, Encoding::SJIS)
    assert_equal 0, regexp =~ "漢"
    error = assert_raises(Encoding::CompatibilityError) do
      regexp =~ "漢".encode(Encoding::Windows_31J)
    end
    assert_equal(
      "incompatible encoding regexp match (UTF-8 regexp with Windows-31J string)",
      error.message
    )
  end

  # 対象エンコーディングに存在しない文字を含む文字種は、正規表現の生成自体が失敗する
  def test_regexp_raises_when_char_class_is_not_representable_in_encoding
    [Moji::ALL, Moji::ZEN, Moji::ZEN_JSYMBOL].each do |type|
      [Encoding::Shift_JIS, Encoding::Windows_31J, Encoding::EUC_JP].each do |encoding|
        assert_raises(Encoding::UndefinedConversionError, "type=#{type} enc=#{encoding}") do
          Moji.regexp(type, encoding)
        end
      end
    end

    # ZEN_ASYMBOL は "－"(U+FF0D) を含むため Shift_JIS / EUC-JP では失敗するが、
    # Windows-31J は U+FF0D を持つので成功する
    error = assert_raises(Encoding::UndefinedConversionError) do
      Moji.regexp(Moji::ZEN_ASYMBOL, Encoding::Shift_JIS)
    end
    assert_equal "U+FF0D from UTF-8 to Shift_JIS", error.message
    assert_raises(Encoding::UndefinedConversionError) do
      Moji.regexp(Moji::ZEN_ASYMBOL, Encoding::EUC_JP)
    end
    assert_equal(
      Encoding::Windows_31J,
      Moji.regexp(Moji::ZEN_ASYMBOL, Encoding::Windows_31J).encoding
    )

    # ZEN_JSYMBOL は "〜"(U+301C) と "～"(U+FF5E) の両方を含み、
    # どちらが先に落ちるかはエンコーディングによって変わる
    error = assert_raises(Encoding::UndefinedConversionError) do
      Moji.regexp(Moji::ZEN_JSYMBOL, Encoding::Windows_31J)
    end
    assert_equal "U+301C from UTF-8 to Windows-31J", error.message
    error = assert_raises(Encoding::UndefinedConversionError) do
      Moji.regexp(Moji::ZEN_JSYMBOL, Encoding::Shift_JIS)
    end
    assert_equal "U+FF5E from UTF-8 to Shift_JIS", error.message
  end

  # --------------------------------------------------------------------------
  # 引数なしの Moji.regexp と動的メソッド
  # --------------------------------------------------------------------------

  # 非 ASCII を含む文字種は UTF-8、ASCII のみの文字種は US-ASCII になる
  # （ドキュメントは「UTF-8 を返す」としているが、実挙動は文字種によって異なる）
  def test_regexp_without_encoding_returns_utf8_or_us_ascii_by_type
    {
      Moji::HIRA => Encoding::UTF_8,
      Moji::ZEN_KATA => Encoding::UTF_8,
      Moji::HAN_KATA => Encoding::UTF_8,
      Moji::ZEN_KANJI => Encoding::UTF_8,
      Moji::ALL => Encoding::UTF_8,
      Moji::HAN_NUMBER => Encoding::US_ASCII,
      Moji::HAN_UPPER => Encoding::US_ASCII,
      Moji::HAN_CONTROL => Encoding::US_ASCII,
    }.each do |type, expected|
      assert_equal expected, Moji.regexp(type).encoding, "type=#{type}"
    end

    assert_equal "[ぁ-ん]", Moji.regexp(Moji::HIRA).source
    assert_equal 0, Moji.regexp(Moji::HIRA) =~ "あ"
  end

  def test_dynamic_methods_return_same_regexp_as_regexp_method
    assert_equal Moji.regexp(Moji::HIRA).source, Moji.hira.source
    assert_equal Moji.regexp(Moji::HIRA).encoding, Moji.hira.encoding
    assert_equal Moji.regexp(Moji::KATA).source, Moji.kata.source
    assert_equal Moji.regexp(Moji::ZEN_KANJI).source, Moji.zen_kanji.source
    assert_equal Moji.regexp(Moji::HAN_NUMBER).source, Moji.han_number.source

    assert_equal Encoding::UTF_8, Moji.hira.encoding
    assert_equal Encoding::UTF_8, Moji.kata.encoding
    assert_equal Encoding::US_ASCII, Moji.han_number.encoding
    assert_equal Encoding::US_ASCII, Moji.han_lower.encoding
  end

  def test_dynamic_methods_accept_encoding_argument
    assert_equal Encoding::Windows_31J, Moji.kata(Encoding::SJIS).encoding
    assert_equal 0, Moji.kata(Encoding::SJIS) =~ "ｱ".encode(Encoding::Windows_31J)

    assert_equal Encoding::EUC_JP, Moji.hira(Encoding::EUC_JP).encoding
    assert_equal 0, Moji.hira(Encoding::EUC_JP) =~ "あ".encode(Encoding::EUC_JP)

    assert_equal Encoding::Shift_JIS, Moji.zen_kata(Encoding::Shift_JIS).encoding
    assert_equal Encoding::US_ASCII, Moji.han_number(Encoding::SJIS).encoding
    # ZEN_KANJI は encoding 引数を無視して UTF-8 のまま
    assert_equal Encoding::UTF_8, Moji.zen_kanji(Encoding::SJIS).encoding

    # ALL は SJIS へ変換できない文字を含むため、動的メソッド経由でも例外になる
    error = assert_raises(Encoding::UndefinedConversionError) { Moji.all(Encoding::SJIS) }
    assert_equal "U+301C from UTF-8 to Windows-31J", error.message
  end

  # --------------------------------------------------------------------------
  # Encoding.default_internal
  # --------------------------------------------------------------------------

  def test_regexp_follows_default_internal
    with_default_internal(Encoding::EUC_JP) do
      assert_equal Encoding::EUC_JP, Moji.hira.encoding
      assert_equal Encoding::EUC_JP, Moji.regexp(Moji::HIRA).encoding
      assert_equal 0, Moji.hira =~ "あ".encode(Encoding::EUC_JP)
      # ASCII のみの文字種は default_internal に関わらず US-ASCII
      assert_equal Encoding::US_ASCII, Moji.han_number.encoding
      # encoding 引数は default_internal より優先される
      assert_equal Encoding::UTF_8, Moji.regexp(Moji::HIRA, Encoding::UTF_8).encoding
    end
    assert_nil Encoding.default_internal
    assert_equal Encoding::UTF_8, Moji.hira.encoding
  end

  def test_default_internal_shift_jis_makes_all_regexp_raise
    with_default_internal(Encoding::Shift_JIS) do
      assert_equal Encoding::Shift_JIS, Moji.hira.encoding
      assert_equal Encoding::Shift_JIS, Moji.zen_kata.encoding
      error = assert_raises(Encoding::UndefinedConversionError) { Moji.all }
      assert_equal "U+FF0D from UTF-8 to Shift_JIS", error.message
      assert_raises(Encoding::UndefinedConversionError) { Moji.regexp(Moji::ZEN_JSYMBOL) }
    end
    assert_equal Encoding::UTF_8, Moji.hira.encoding
  end

  def test_default_internal_utf8_behaves_like_unset
    with_default_internal(Encoding::UTF_8) do
      assert_equal Encoding::UTF_8, Moji.hira.encoding
      assert_equal Encoding::US_ASCII, Moji.han_number.encoding
      assert_equal Encoding::UTF_8, Moji.regexp(Moji::ALL).encoding
    end
  end

  # 変換系メソッドの返値エンコーディングは default_internal ではなく入力に従う
  def test_conversion_methods_ignore_default_internal
    with_default_internal(Encoding::Shift_JIS) do
      utf8 = Moji.zen_to_han("Ａ")
      assert_equal "A", utf8
      assert_equal Encoding::UTF_8, utf8.encoding

      euc = Moji.zen_to_han("Ａ".encode(Encoding::EUC_JP))
      assert_equal Encoding::EUC_JP, euc.encoding
      assert_equal "A", euc.encode(Encoding::UTF_8)
    end
  end

  # --------------------------------------------------------------------------
  # US-ASCII 入力
  # --------------------------------------------------------------------------

  def test_us_ascii_input_keeps_us_ascii_when_result_is_ascii
    src = "abc".encode(Encoding::US_ASCII)

    {
      zen_to_han: "abc",
      kata_to_hira: "abc",
      hira_to_kata: "abc",
      normalize_zen_han: "abc",
      upcase: "ABC",
      downcase: "abc",
    }.each do |method, expected|
      result = Moji.send(method, src)
      assert_equal expected, result, method.to_s
      assert_equal Encoding::US_ASCII, result.encoding, method.to_s
    end

    assert_equal Moji::HAN_LOWER, Moji.type("a".encode(Encoding::US_ASCII))
    assert Moji.type?("a".encode(Encoding::US_ASCII), Moji::HAN)
  end

  # han_to_zen は結果が全角になり US-ASCII へ戻せないので例外になる
  def test_us_ascii_input_raises_on_han_to_zen
    src = "abc".encode(Encoding::US_ASCII)
    error = assert_raises(Encoding::UndefinedConversionError) { Moji.han_to_zen(src) }
    assert_equal "U+FF41 from UTF-8 to US-ASCII", error.message
  end

  # --------------------------------------------------------------------------
  # frozen 文字列
  # --------------------------------------------------------------------------

  def test_frozen_input_is_accepted
    assert_equal "アイウ", Moji.han_to_zen("ｱｲｳ")
    assert_equal "ｱｲｳ", Moji.zen_to_han("アイウ")
    assert_equal "あいう", Moji.kata_to_hira("アイウ")
    assert_equal Moji::ZEN_KANJI, Moji.type("漢")

    frozen_sjis = "ｱｲｳ".encode(Encoding::Windows_31J).freeze
    result = Moji.han_to_zen(frozen_sjis)
    assert_equal Encoding::Windows_31J, result.encoding
    assert_equal "アイウ", result.encode(Encoding::UTF_8)
    refute_predicate result, :frozen?
  end

  # 変換対象の文字種が 1 つも該当しない場合でもエラーにならない。
  # （現行実装は tr を 1 度も呼ばないため入力オブジェクトをそのまま返すが、
  #   オブジェクト同一性は実装詳細なので内容とエンコーディングだけを固定する）
  def test_frozen_input_accepted_when_nothing_to_convert
    src = "abc"
    result = Moji.zen_to_han(src, Moji::HAN)
    assert_equal "abc", result
    assert_equal Encoding::UTF_8, result.encoding
  end

  # --------------------------------------------------------------------------
  # 変換不能文字
  # --------------------------------------------------------------------------

  # SJIS に無い文字（B 面の漢字・絵文字）を含む UTF-8 文字列はそのまま処理できる
  def test_utf8_input_with_chars_outside_shift_jis
    src = "𠮷野家🍣①ｱ"
    assert_equal "𠮷野家🍣①ｱ", Moji.zen_to_han(src)
    assert_equal "𠮷野家🍣①ア", Moji.han_to_zen(src)
    assert_equal "𠮷野家🍣①ｱ", Moji.kata_to_hira(src)
    assert_equal "𠮷野家🍣①ア", Moji.normalize_zen_han(src)
    assert_equal Encoding::UTF_8, Moji.han_to_zen(src).encoding
    assert_nil Moji.type("𠮷")
    assert_nil Moji.type("🍣")
  end

  # 結果を入力エンコーディングへ戻せない実例:
  # 半角ハイフン "-" の全角 "－"(U+FF0D) は Windows-31J にはあるが Shift_JIS / EUC-JP には無い
  def test_han_to_zen_raises_when_result_is_not_representable_in_input_encoding
    error = assert_raises(Encoding::UndefinedConversionError) do
      Moji.han_to_zen("-".encode(Encoding::Shift_JIS))
    end
    assert_equal "U+FF0D from UTF-8 to Shift_JIS", error.message

    error = assert_raises(Encoding::UndefinedConversionError) do
      Moji.han_to_zen("-".encode(Encoding::EUC_JP))
    end
    assert_equal "U+FF0D from UTF-8 to EUC-JP", error.message

    # Windows-31J なら成功する
    result = Moji.han_to_zen("-".encode(Encoding::Windows_31J))
    assert_equal Encoding::Windows_31J, result.encoding
    assert_equal "－", result.encode(Encoding::UTF_8)

    # normalize_zen_han は ASCII 記号を全角化しないので Shift_JIS でも成功する
    normalized = Moji.normalize_zen_han("-".encode(Encoding::Shift_JIS))
    assert_equal Encoding::Shift_JIS, normalized.encoding
    assert_equal "-", normalized.encode(Encoding::UTF_8)
  end
end
