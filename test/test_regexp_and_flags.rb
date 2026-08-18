# frozen_string_literal: true

require "test_helper"

# Moji.regexp / 動的正規表現メソッド / フラグ定数の振る舞いを固定するゴールデンテスト。
# 期待値はすべて現行実装（本家 1.6 相当）の実行結果から採取している。
# 直感に反する挙動（バグに見えるもの）もそのまま固定する。
class TestRegexpAndFlags < Minitest::Test
  include MojiTestHelpers

  # 基本 18 文字種。並び順はビット位置（HAN_CONTROL が bit 0）に対応する。
  # 将来定数が増えても既存分の互換を固定するため、リストはテスト側にリテラルで持つ。
  BASE_FLAG_NAMES = %w[
    HAN_CONTROL HAN_ASYMBOL HAN_JSYMBOL HAN_NUMBER HAN_UPPER HAN_LOWER HAN_KATA
    ZEN_ASYMBOL ZEN_JSYMBOL ZEN_NUMBER ZEN_UPPER ZEN_LOWER ZEN_HIRA ZEN_KATA
    ZEN_GREEK ZEN_CYRILLIC ZEN_LINE ZEN_KANJI
  ].freeze

  # 合成定数・別名定数。
  COMPOSITE_FLAG_NAMES = %w[
    HAN_SYMBOL HAN_ALPHA HAN_ALNUM HAN
    ZEN_SYMBOL ZEN_ALPHA ZEN_ALNUM ZEN_KANA ZEN
    ASYMBOL JSYMBOL SYMBOL NUMBER UPPER LOWER ALPHA ALNUM
    HIRA KATA KANA GREEK CYRILLIC LINE KANJI ALL
  ].freeze

  ALL_FLAG_NAMES = (BASE_FLAG_NAMES + COMPOSITE_FLAG_NAMES).freeze

  # BASE_FLAG_NAMES と同じ並びの代表文字。どの文字も 1 つの基本文字種にしか属さない。
  BASE_SAMPLE_CHARS = [
    "\n", "!", "｡", "7", "R", "r", "ﾄ",
    "！", "。", "７", "Ｒ", "ｒ", "あ", "ア",
    "Α", "Я", "╰", "漢",
  ].freeze

  # 基本 18 文字種の正規表現の source（CHAR_REGEXPS のリテラルそのもの）。
  BASE_SOURCES = {
    "HAN_CONTROL" => "[\\x00-\\x1f\\x7f]",
    "HAN_ASYMBOL" => "[ !\"\#$%&'()*+,\\-./:;<=>?@\\[\\\\\\]\\^_`{|}~]",
    "HAN_JSYMBOL" => "[｡｢｣､ｰﾞﾟ･]",
    "HAN_NUMBER" => "[0-9]",
    "HAN_UPPER" => "[A-Z]",
    "HAN_LOWER" => "[a-z]",
    "HAN_KATA" => "[ｦ-ｯｱ-ﾝ]",
    "ZEN_ASYMBOL" => "[　！”＃＄％＆’（）＊＋，－．／：；＜＝＞？＠［￥］＾＿‘｛｜｝￣]",
    "ZEN_JSYMBOL" => "[、。・゛゜´｀¨ヽヾゝゞ〃仝々〆〇ー―‐＼～〜∥…‥“〔〕〈〉《》「」『』【】" \
                     "±×÷≠≦≧∞∴♂♀°′″℃￠￡§☆★○●◎◇◇◆□■△▲▽▼※〒→←↑↓〓]",
    "ZEN_NUMBER" => "[０-９]",
    "ZEN_UPPER" => "[Ａ-Ｚ]",
    "ZEN_LOWER" => "[ａ-ｚ]",
    "ZEN_HIRA" => "[ぁ-ん]",
    "ZEN_KATA" => "[ァ-ヶ]",
    "ZEN_GREEK" => "[Α-Ωα-ω]",
    "ZEN_CYRILLIC" => "[А-Яа-я]",
    "ZEN_LINE" => "[\\u2570-\\u25ff]",
    "ZEN_KANJI" => "[\\u3400-\\u4dbf\\u4e00-\\u9fff\\uf900-\\ufaff]",
  }.freeze

  # 全フラグ定数の to_i 実測値。
  FLAG_VALUES = {
    "HAN_CONTROL" => 1,
    "HAN_ASYMBOL" => 2,
    "HAN_JSYMBOL" => 4,
    "HAN_NUMBER" => 8,
    "HAN_UPPER" => 16,
    "HAN_LOWER" => 32,
    "HAN_KATA" => 64,
    "ZEN_ASYMBOL" => 128,
    "ZEN_JSYMBOL" => 256,
    "ZEN_NUMBER" => 512,
    "ZEN_UPPER" => 1024,
    "ZEN_LOWER" => 2048,
    "ZEN_HIRA" => 4096,
    "ZEN_KATA" => 8192,
    "ZEN_GREEK" => 16_384,
    "ZEN_CYRILLIC" => 32_768,
    "ZEN_LINE" => 65_536,
    "ZEN_KANJI" => 131_072,
    "HAN_SYMBOL" => 6,
    "HAN_ALPHA" => 48,
    "HAN_ALNUM" => 56,
    "HAN" => 127,
    "ZEN_SYMBOL" => 384,
    "ZEN_ALPHA" => 3072,
    "ZEN_ALNUM" => 3584,
    "ZEN_KANA" => 12_288,
    "ZEN" => 262_016,
    "ASYMBOL" => 130,
    "JSYMBOL" => 260,
    "SYMBOL" => 390,
    "NUMBER" => 520,
    "UPPER" => 1040,
    "LOWER" => 2080,
    "ALPHA" => 3120,
    "ALNUM" => 3640,
    "HIRA" => 4096,
    "KATA" => 8256,
    "KANA" => 12_352,
    "GREEK" => 16_384,
    "CYRILLIC" => 32_768,
    "LINE" => 65_536,
    "KANJI" => 131_072,
    "ALL" => 262_143,
  }.freeze

  # 全フラグ定数の to_s 実測値。単一ビットは名前そのまま、複数ビットは "(A|B)" 形式。
  FLAG_TO_S = {
    "HAN_CONTROL" => "HAN_CONTROL",
    "HAN_ASYMBOL" => "HAN_ASYMBOL",
    "HAN_JSYMBOL" => "HAN_JSYMBOL",
    "HAN_NUMBER" => "HAN_NUMBER",
    "HAN_UPPER" => "HAN_UPPER",
    "HAN_LOWER" => "HAN_LOWER",
    "HAN_KATA" => "HAN_KATA",
    "ZEN_ASYMBOL" => "ZEN_ASYMBOL",
    "ZEN_JSYMBOL" => "ZEN_JSYMBOL",
    "ZEN_NUMBER" => "ZEN_NUMBER",
    "ZEN_UPPER" => "ZEN_UPPER",
    "ZEN_LOWER" => "ZEN_LOWER",
    "ZEN_HIRA" => "ZEN_HIRA",
    "ZEN_KATA" => "ZEN_KATA",
    "ZEN_GREEK" => "ZEN_GREEK",
    "ZEN_CYRILLIC" => "ZEN_CYRILLIC",
    "ZEN_LINE" => "ZEN_LINE",
    "ZEN_KANJI" => "ZEN_KANJI",
    "HAN_SYMBOL" => "(HAN_ASYMBOL|HAN_JSYMBOL)",
    "HAN_ALPHA" => "(HAN_UPPER|HAN_LOWER)",
    "HAN_ALNUM" => "(HAN_NUMBER|HAN_UPPER|HAN_LOWER)",
    "HAN" => "(HAN_CONTROL|HAN_ASYMBOL|HAN_JSYMBOL|HAN_NUMBER|HAN_UPPER|HAN_LOWER|HAN_KATA)",
    "ZEN_SYMBOL" => "(ZEN_ASYMBOL|ZEN_JSYMBOL)",
    "ZEN_ALPHA" => "(ZEN_UPPER|ZEN_LOWER)",
    "ZEN_ALNUM" => "(ZEN_NUMBER|ZEN_UPPER|ZEN_LOWER)",
    "ZEN_KANA" => "(ZEN_HIRA|ZEN_KATA)",
    "ZEN" => "(ZEN_ASYMBOL|ZEN_JSYMBOL|ZEN_NUMBER|ZEN_UPPER|ZEN_LOWER|ZEN_HIRA|ZEN_KATA|" \
             "ZEN_GREEK|ZEN_CYRILLIC|ZEN_LINE|ZEN_KANJI)",
    "ASYMBOL" => "(HAN_ASYMBOL|ZEN_ASYMBOL)",
    "JSYMBOL" => "(HAN_JSYMBOL|ZEN_JSYMBOL)",
    "SYMBOL" => "(HAN_ASYMBOL|HAN_JSYMBOL|ZEN_ASYMBOL|ZEN_JSYMBOL)",
    "NUMBER" => "(HAN_NUMBER|ZEN_NUMBER)",
    "UPPER" => "(HAN_UPPER|ZEN_UPPER)",
    "LOWER" => "(HAN_LOWER|ZEN_LOWER)",
    "ALPHA" => "(HAN_UPPER|HAN_LOWER|ZEN_UPPER|ZEN_LOWER)",
    "ALNUM" => "(HAN_NUMBER|HAN_UPPER|HAN_LOWER|ZEN_NUMBER|ZEN_UPPER|ZEN_LOWER)",
    "HIRA" => "ZEN_HIRA",
    "KATA" => "(HAN_KATA|ZEN_KATA)",
    "KANA" => "(HAN_KATA|ZEN_HIRA|ZEN_KATA)",
    "GREEK" => "ZEN_GREEK",
    "CYRILLIC" => "ZEN_CYRILLIC",
    "LINE" => "ZEN_LINE",
    "KANJI" => "ZEN_KANJI",
    "ALL" => "(HAN_CONTROL|HAN_ASYMBOL|HAN_JSYMBOL|HAN_NUMBER|HAN_UPPER|HAN_LOWER|HAN_KATA|" \
             "ZEN_ASYMBOL|ZEN_JSYMBOL|ZEN_NUMBER|ZEN_UPPER|ZEN_LOWER|ZEN_HIRA|ZEN_KATA|" \
             "ZEN_GREEK|ZEN_CYRILLIC|ZEN_LINE|ZEN_KANJI)",
  }.freeze

  def flag(name)
    Moji.const_get(name)
  end

  # FLAG_VALUES（テスト側リテラル）のビットから、その定数が含む基本文字種の添字を求める。
  def expected_member_indexes(name)
    value = FLAG_VALUES.fetch(name)
    BASE_FLAG_NAMES.each_index.select { |i| value[i] == 1 }
  end

  # ---- 定数の存在 ----

  def test_all_flag_constants_are_defined
    ALL_FLAG_NAMES.each do |name|
      assert(Moji.const_defined?(name), "Moji::#{name} が未定義")
    end
  end

  # ---- Moji.regexp: 単一文字種 ----

  def test_regexp_for_single_flag_has_expected_source
    BASE_FLAG_NAMES.each do |name|
      assert_equal(BASE_SOURCES.fetch(name), Moji.regexp(flag(name)).source, name)
    end
  end

  def test_regexp_for_single_flag_matches_only_its_own_char_type
    # 基本 18 文字種の代表文字と正規表現の対応は完全な対角行列になる。
    BASE_FLAG_NAMES.each_with_index do |name, i|
      re = Moji.regexp(flag(name))
      BASE_FLAG_NAMES.each_index do |j|
        ch = BASE_SAMPLE_CHARS[j]
        if i == j
          assert_equal(0, ch =~ re, "#{name} が #{ch.inspect} にマッチしない")
        else
          assert_nil(ch =~ re, "#{name} が #{ch.inspect} にマッチしてしまう")
        end
      end
    end
  end

  def test_regexp_matches_a_single_character
    # 1 文字ぶんの正規表現なので、複数文字の並びに対しては先頭 1 文字だけを捉える。
    assert_equal("ア", "アイウ"[Moji.regexp(Moji::ZEN_KATA)])
    assert_equal("R", "Ruby"[Moji.regexp(Moji::HAN_UPPER)])
  end

  # ---- Moji.regexp: 合成文字種 ----

  def test_regexp_for_composite_flag_matches_exactly_its_member_types
    COMPOSITE_FLAG_NAMES.each do |name|
      re = Moji.regexp(flag(name))
      members = expected_member_indexes(name)
      BASE_FLAG_NAMES.each_index do |j|
        ch = BASE_SAMPLE_CHARS[j]
        if members.include?(j)
          assert_equal(0, ch =~ re, "#{name} が #{ch.inspect} にマッチしない")
        else
          assert_nil(ch =~ re, "#{name} が #{ch.inspect} にマッチしてしまう")
        end
      end
    end
  end

  def test_regexp_for_kana_matches_han_kata_hira_and_zen_kata
    re = Moji.regexp(Moji::KANA)
    %w[ﾄ あ ア].each { |ch| assert_equal(0, ch =~ re, ch) }
    %w[R ７ 漢].each { |ch| assert_nil(ch =~ re, ch) }
  end

  def test_regexp_for_alnum_matches_han_and_zen_alnum
    re = Moji.regexp(Moji::ALNUM)
    %w[7 R r ７ Ｒ ｒ].each { |ch| assert_equal(0, ch =~ re, ch) }
    ["あ", "！", "漢"].each { |ch| assert_nil(ch =~ re, ch) }
  end

  def test_regexp_for_all_matches_every_base_sample
    re = Moji.regexp(Moji::ALL)
    BASE_SAMPLE_CHARS.each { |ch| assert_equal(0, ch =~ re, ch.inspect) }
    # ALL に含まれない文字（ハングル・B 面漢字）はマッチしない。
    assert_nil("한" =~ re)
    assert_nil("𠀋" =~ re)
  end

  def test_regexp_source_for_composite_flag_joins_members_with_alternation
    # 合成文字種は各要素の Regexp#to_s を "|" で連結するため、(?-mix:) が source に露出する。
    assert_equal("(?-mix:[ｦ-ｯｱ-ﾝ])|(?-mix:[ァ-ヶ])", Moji.regexp(Moji::KATA).source)
    assert_equal("(?-mix:[0-9])|(?-mix:[０-９])", Moji.regexp(Moji::NUMBER).source)
  end

  # ---- 動的に定義される正規表現メソッド ----

  def test_downcased_method_is_defined_for_every_flag_constant
    ALL_FLAG_NAMES.each do |name|
      assert(Moji.respond_to?(name.downcase), "Moji.#{name.downcase} が未定義")
    end
  end

  def test_downcased_method_returns_same_regexp_as_regexp_with_constant
    ALL_FLAG_NAMES.each do |name|
      expected = Moji.regexp(flag(name))
      actual = Moji.public_send(name.downcase)
      assert_equal(expected.source, actual.source, "Moji.#{name.downcase} の source")
      assert_equal(expected.encoding, actual.encoding, "Moji.#{name.downcase} の encoding")
    end
  end

  def test_downcased_method_shortcuts_documented_in_rd
    assert_equal(Moji.regexp(Moji::KANA).source, Moji.kana.source)
    assert_equal("[ぁ-ん]", Moji.hira.source)
    assert_equal("[ァ-ヶ]", Moji.zen_kata.source)
    assert_equal("[\\x00-\\x1f\\x7f]", Moji.han_control.source)
    assert_equal("[\\u3400-\\u4dbf\\u4e00-\\u9fff\\uf900-\\ufaff]", Moji.zen_kanji.source)
  end

  # ---- 正規表現のエンコーディング ----

  def test_regexp_encoding_is_us_ascii_for_ascii_only_char_types
    # ASCII だけで書かれた文字種は US-ASCII の正規表現のまま返る。
    assert_equal(Encoding::US_ASCII, Moji.regexp(Moji::HAN_UPPER).encoding)
    assert_equal(Encoding::UTF_8, Moji.regexp(Moji::ZEN_HIRA).encoding)
  end

  def test_regexp_with_explicit_encoding_returns_regexp_of_that_encoding
    re = Moji.regexp(Moji::HIRA, Encoding::SJIS)
    assert_equal(Encoding::SJIS, re.encoding)
    assert_equal(0, "あ".encode(Encoding::SJIS) =~ re)
    assert_nil("ア".encode(Encoding::SJIS) =~ re)
  end

  def test_downcased_method_accepts_encoding_argument
    re = Moji.kana(Encoding::SJIS)
    assert_equal(Encoding::SJIS, re.encoding)
    assert_equal(0, "ｱ".encode(Encoding::SJIS) =~ re)
    assert_nil("A".encode(Encoding::SJIS) =~ re)
  end

  def test_explicit_utf8_encoding_returns_utf8_regexp
    assert_equal(Encoding::UTF_8, Moji.regexp(Moji::HIRA, Encoding::UTF_8).encoding)
  end

  def test_regexp_follows_default_internal_when_encoding_is_omitted
    orig_internal = Encoding.default_internal
    with_default_internal(Encoding::SJIS) do
      assert_equal(Encoding::SJIS, Moji.hira.encoding)
      assert_equal(Encoding::SJIS, Moji.regexp(Moji::KANA).encoding)
    end
    assert_equal(orig_internal || Encoding::UTF_8, Moji.hira.encoding)
  end

  # 同じ文字種でも default_internal を切り替えるたびに、その時点の解決後
  # エンコーディングの正規表現が返る（キャッシュ・メモ化を導入しても、
  # 直前の設定で作った結果を別エンコーディング設定下で返してはいけない）。
  def test_regexp_tracks_default_internal_switches_for_same_type
    utf8_before = Moji.regexp(Moji::HIRA)
    assert_equal(Encoding::UTF_8, utf8_before.encoding)
    with_default_internal(Encoding::SJIS) do
      assert_equal(Encoding::SJIS, Moji.regexp(Moji::HIRA).encoding)
    end
    utf8_after = Moji.regexp(Moji::HIRA)
    assert_equal(Encoding::UTF_8, utf8_after.encoding)
    assert_equal(utf8_before.source, utf8_after.source)
  end

  # ---- 実利用例（文字列補間） ----

  def test_zen_kata_interpolated_into_character_class
    # 社内コードの実利用パターン。文字クラスの中に正規表現を補間している。
    re = /\A[#{Moji.zen_kata}|ー|－]{1,20}\z/
    assert_equal("\\A[(?-mix:[ァ-ヶ])|ー|－]{1,20}\\z", re.source)
    assert_match(re, "ドラエモン")
    assert_match(re, "ドラエモンー")
    assert_match(re, "ドラエモン－")
    refute_match(re, "どらえもん")
    refute_match(re, "ﾄﾞﾗｴﾓﾝ")
    assert_match(re, "ア" * 20)
    refute_match(re, "ア" * 21)
    refute_match(re, "")
  end

  def test_zen_kata_interpolation_leaks_wrapper_characters_into_character_class
    # (?-mix:...) の文字がそのまま文字クラスの要素になるため、
    # "(" や "x" のような無関係な半角文字までマッチしてしまう。
    re = /\A[#{Moji.zen_kata}|ー|－]{1,20}\z/
    assert_match(re, "x")
    assert_match(re, "mix")
    assert_match(re, "(")
  end

  def test_kata_then_hira_interpolation_matches_at_character_offset
    # RD ドキュメントの例。1.8 時代は 6（バイト位置）だったが、
    # 1.9 以降は文字位置を返すため 2 になる。
    assert_equal(2, /#{Moji.kata}+#{Moji.hira}+/ =~ "ぼくドラえもん")
    assert_equal("ドラえもん", Regexp.last_match.to_s)
  end

  # ---- フラグ定数の値 ----

  def test_flag_to_i_values
    FLAG_VALUES.each do |name, value|
      assert_equal(value, flag(name).to_i, "Moji::#{name}")
    end
  end

  def test_base_flags_occupy_one_bit_each_in_declaration_order
    BASE_FLAG_NAMES.each_with_index do |name, i|
      assert_equal(1 << i, flag(name).to_i, "Moji::#{name}")
    end
  end

  def test_all_has_all_18_bits_set
    assert_equal(262_143, Moji::ALL.to_i)
    assert_equal((1 << 18) - 1, Moji::ALL.to_i)
  end

  def test_composite_flag_equals_or_of_its_members
    composites = {
      "HAN_SYMBOL" => %w[HAN_ASYMBOL HAN_JSYMBOL],
      "HAN_ALPHA" => %w[HAN_UPPER HAN_LOWER],
      "HAN_ALNUM" => %w[HAN_UPPER HAN_LOWER HAN_NUMBER],
      "HAN" => %w[HAN_CONTROL HAN_ASYMBOL HAN_JSYMBOL HAN_NUMBER HAN_UPPER HAN_LOWER HAN_KATA],
      "ZEN_SYMBOL" => %w[ZEN_ASYMBOL ZEN_JSYMBOL],
      "ZEN_ALPHA" => %w[ZEN_UPPER ZEN_LOWER],
      "ZEN_ALNUM" => %w[ZEN_UPPER ZEN_LOWER ZEN_NUMBER],
      "ZEN_KANA" => %w[ZEN_KATA ZEN_HIRA],
      "ZEN" => %w[ZEN_ASYMBOL ZEN_JSYMBOL ZEN_NUMBER ZEN_UPPER ZEN_LOWER ZEN_HIRA ZEN_KATA
                  ZEN_GREEK ZEN_CYRILLIC ZEN_LINE ZEN_KANJI],
      "ASYMBOL" => %w[HAN_ASYMBOL ZEN_ASYMBOL],
      "JSYMBOL" => %w[HAN_JSYMBOL ZEN_JSYMBOL],
      "SYMBOL" => %w[HAN_ASYMBOL HAN_JSYMBOL ZEN_ASYMBOL ZEN_JSYMBOL],
      "NUMBER" => %w[HAN_NUMBER ZEN_NUMBER],
      "UPPER" => %w[HAN_UPPER ZEN_UPPER],
      "LOWER" => %w[HAN_LOWER ZEN_LOWER],
      "ALPHA" => %w[HAN_UPPER HAN_LOWER ZEN_UPPER ZEN_LOWER],
      "ALNUM" => %w[HAN_NUMBER HAN_UPPER HAN_LOWER ZEN_NUMBER ZEN_UPPER ZEN_LOWER],
      "KATA" => %w[HAN_KATA ZEN_KATA],
      "KANA" => %w[HAN_KATA ZEN_KATA ZEN_HIRA],
      "ALL" => BASE_FLAG_NAMES,
    }
    composites.each do |name, members|
      expected = members.map { |m| flag(m).to_i }.inject(0) { |a, b| a | b }
      assert_equal(expected, flag(name).to_i, "Moji::#{name}")
      or_flag = members.map { |m| flag(m) }.inject { |a, b| a | b }
      assert_equal(or_flag, flag(name), "Moji::#{name}")
    end
  end

  def test_alias_constants_equal_their_source_constant
    assert_equal(Moji::ZEN_HIRA, Moji::HIRA)
    assert_equal(Moji::ZEN_GREEK, Moji::GREEK)
    assert_equal(Moji::ZEN_CYRILLIC, Moji::CYRILLIC)
    assert_equal(Moji::ZEN_LINE, Moji::LINE)
    assert_equal(Moji::ZEN_KANJI, Moji::KANJI)
  end

  # ---- フラグ演算 ----

  def test_flag_or_operator
    assert_equal(Moji::HAN_ALPHA, Moji::HAN_UPPER | Moji::HAN_LOWER)
    assert_equal(48, (Moji::HAN_UPPER | Moji::HAN_LOWER).to_i)
    assert_equal(Moji::ALL, Moji::HAN | Moji::ZEN)
  end

  def test_flag_and_operator
    assert_equal(Moji::ZEN_HIRA, Moji::ALL & Moji::HIRA)
    assert_equal(Moji::HAN_KATA, Moji::KANA & Moji::HAN)
    # HAN と ZEN は互いに素なので 0 になる。
    assert_equal(0, (Moji::HAN & Moji::ZEN).to_i)
  end

  def test_flag_not_operator_is_masked_to_18_bits
    assert_equal(262_142, (~Moji::HAN_CONTROL).to_i)
    assert_equal(Moji::ZEN, ~Moji::HAN)
    # 全ビット立ちの補集合は 0（負数にはならない）。
    assert_equal(0, (~Moji::ALL).to_i)
  end

  def test_flag_include
    assert(Moji::HAN_UPPER.include?(Moji::HAN_UPPER), "自分自身を含む")
    assert(Moji::ALL.include?(Moji::HAN), "上位集合は部分集合を含む")
    refute(Moji::HAN.include?(Moji::ALL), "部分集合は上位集合を含まない")
    refute(Moji::HAN.include?(Moji::ZEN_KANJI), "無関係な文字種は含まない")
    assert(Moji::KANA.include?(Moji::ZEN_HIRA))
    assert(Moji::KANA.include?(Moji::HAN_KATA))
    refute(Moji::ZEN_KANA.include?(Moji::HAN_KATA))
  end

  def test_flag_include_with_nil_returns_true
    # nil.to_i == 0 になるため、どのフラグも nil を「含む」と答える。
    # Moji.type? が未知の文字（type が nil）に対して true を返す原因。
    assert(Moji::HAN_UPPER.include?(nil))
    assert(Moji::ALL.include?(nil))
  end

  def test_empty_p_is_inverted
    # empty? の実装は @value != 0 を返しており、名前と意味が逆。
    assert(Moji::ALL.empty?, "ビットが立っているのに empty? は true")
    # rubocop:disable Style/ArrayIntersect -- Flags の & は Array ではないので intersect? に書き換えてはいけない
    refute((Moji::HAN & Moji::ZEN).empty?, "ビットが 0 なのに empty? は false")
    # rubocop:enable Style/ArrayIntersect
  end

  # ---- 名前空間契約 ----

  # CHANGELOG が後方互換の契約として示す「FlagSetMaker は Moji::FlagSetMaker へ移動、
  # トップレベルには置かない」を固定する。
  def test_flags_class_lives_under_moji_namespace
    assert(defined?(Moji::FlagSetMaker::Flags))
    assert_instance_of(Moji::FlagSetMaker::Flags, Moji.type("漢"))
    assert_instance_of(Moji::FlagSetMaker::Flags, Moji::ALL)
    refute(defined?(::FlagSetMaker), "トップレベルに FlagSetMaker を定義しない契約")
  end

  # ---- 等値性・ハッシュ ----

  def test_flag_equality
    assert_equal(Moji::HIRA, Moji::ZEN_HIRA)
    assert(Moji::HIRA == Moji::ZEN_HIRA)
    assert(Moji::HIRA.eql?(Moji::ZEN_HIRA))
    refute(Moji::HIRA == Moji::ZEN_KATA)
  end

  def test_flag_is_not_equal_to_integer
    # 比較相手が Flags でなければ常に false（Integer との相互変換はしない）。
    refute(Moji::HIRA == 4096)
    refute(Moji::HIRA.eql?(4096))
    refute(Moji::HIRA.nil?)
  end

  def test_flag_hash_is_delegated_to_to_i
    assert_equal(Moji::ZEN_HIRA.hash, Moji::HIRA.hash)
    assert_equal(4096.hash, Moji::HIRA.hash)
    # 同値のフラグは Hash のキーとして同一視される。
    table = { Moji::HIRA => "ひらがな" }
    assert_equal("ひらがな", table[Moji::ZEN_HIRA])
    table[Moji::ZEN_HIRA] = "上書き"
    assert_equal(1, table.size)
  end

  # ---- to_s / inspect ----

  def test_flag_to_s
    FLAG_TO_S.each do |name, expected|
      assert_equal(expected, flag(name).to_s, "Moji::#{name}")
    end
  end

  def test_flag_to_s_lists_names_in_bit_order_not_definition_order
    # ZEN_KANA は ZEN_KATA | ZEN_HIRA として定義されているが、
    # to_s はビットの昇順（ZEN_HIRA が先）で並べる。
    assert_equal("(ZEN_HIRA|ZEN_KATA)", Moji::ZEN_KANA.to_s)
    assert_equal("(HAN_KATA|ZEN_HIRA|ZEN_KATA)", Moji::KANA.to_s)
  end

  def test_flag_inspect_prefixes_module_name
    assert_equal("Moji::ZEN_KANJI", Moji::ZEN_KANJI.inspect)
    assert_equal("Moji::HAN_CONTROL", Moji::HAN_CONTROL.inspect)
    assert_equal("Moji::(HAN_ASYMBOL|HAN_JSYMBOL)", Moji::HAN_SYMBOL.inspect)
    assert_equal("Moji::(HAN_KATA|ZEN_HIRA|ZEN_KATA)", Moji::KANA.inspect)
  end

  def test_alias_constant_inspect_shows_the_original_name
    # 別名定数は値しか持たないので、inspect には元の定数名が出る。
    assert_equal("Moji::ZEN_HIRA", Moji::HIRA.inspect)
    assert_equal("Moji::ZEN_KANJI", Moji::KANJI.inspect)
  end

  def test_flag_inspect_for_every_constant_matches_to_s
    ALL_FLAG_NAMES.each do |name|
      assert_equal("Moji::#{FLAG_TO_S.fetch(name)}", flag(name).inspect, "Moji::#{name}")
    end
  end

  # ---- ゼロフラグ ----

  def test_zero_flag_to_s_is_empty_string
    # 名前付きゼロ定数が無いため、to_s は "0" ではなく空文字列になる。
    assert_equal("", (Moji::HAN & Moji::ZEN).to_s)
  end

  def test_zero_flag_inspect_has_no_name_part
    assert_equal("Moji::", (Moji::HAN & Moji::ZEN).inspect)
  end

  def test_regexp_for_zero_flag_is_empty_and_matches_anything
    # 該当する文字種が 1 つも無いと空の正規表現になり、あらゆる文字列にマッチする。
    re = Moji.regexp(Moji::HAN & Moji::ZEN)
    assert_equal("", re.source)
    assert_equal(0, "あ" =~ re)
    assert_equal(0, "" =~ re)
  end

  # ---- Moji.type との連携 ----

  def test_type_result_is_comparable_with_constants
    assert_equal(Moji::ZEN_KANJI, Moji.type("漢"))
    assert_equal(Moji::ZEN_HIRA, Moji.type("あ"))
    assert_equal(Moji::HIRA, Moji.type("あ"))
    assert(Moji.type("Ａ") == Moji::ZEN_UPPER)
    assert(Moji::ZEN.include?(Moji.type("Ａ")))
    refute(Moji::HAN.include?(Moji.type("Ａ")))
  end

  def test_type_result_can_be_used_as_regexp_argument
    assert_equal("[ぁ-ん]", Moji.regexp(Moji.type("あ")).source)
  end

  # ---- 範囲の境界（実装どおりに固定） ----

  def test_zen_line_range_starts_at_u2570
    # 罫線の範囲は 0x2570-0x25FF。フォールバック側の /[─-╂]/ が示す 0x2500 始まりではない。
    assert_nil("─" =~ Moji.line) # U+2500
    assert_equal(0, "╰" =~ Moji.line)  # U+2570
    assert_equal(0, "○" =~ Moji.line)  # U+25CB（ZEN_JSYMBOL にも含まれる）
  end

  def test_kana_ranges_exclude_characters_beyond_their_upper_bound
    assert_equal(0, "ん" =~ Moji.hira)
    assert_nil("ゔ" =~ Moji.hira) # U+3094 は [ぁ-ん] の外
    assert_equal(0, "ヶ" =~ Moji.zen_kata)
    assert_nil("ヷ" =~ Moji.zen_kata) # U+30F7 は [ァ-ヶ] の外
  end

  def test_kanji_regexp_excludes_iteration_mark_and_plane2
    assert_nil("々" =~ Moji.kanji)  # U+3005 は ZEN_JSYMBOL 扱い
    assert_equal(0, "々" =~ Moji.zen_jsymbol)
    assert_nil("𠀋" =~ Moji.kanji)  # SIP（B 面）の漢字は対象外
  end
end
