# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "minitest/autorun"
require "moji"

# 本家 1.6 互換の対応表をテスト側の正データとして 1 か所に持つ。
# lib の Moji::Detail は private 実装なので参照しない（実装と期待値の独立性を保つ）。
# 各テストが使う構造（並行文字列・ペア配列）はここから導出する。
module GoldenFixtures
  # ASCII 記号表は " \ ` #$ を含むためシングルクォートで書く（ダブルクォートだと
  # エスケープ誤りで黙って短くなり、1:1 ループが少ない文字数のまま緑になる）。
  HAN_ASYMBOL_LIST = ' !"#$%&\'()*+,-./:;<=>?@[\]^_`{|}~'
  ZEN_ASYMBOL_LIST = "　！”＃＄％＆’（）＊＋，－．／：；＜＝＞？＠［￥］＾＿‘｛｜｝￣"

  # 半角 JIS 記号の並びは「。「」、ー゛゜・」と対応する。ｰ（長音）はカナ表ではなくこちらにある。
  HAN_JSYMBOL1_LIST = "｡｢｣､ｰﾞﾟ･"
  ZEN_JSYMBOL1_LIST = "。「」、ー゛゜・"

  # ZEN_JSYMBOL の判定対象全文字。◇ U+25C7 が 2 回入っている（本家由来のリスト重複）。
  ZEN_JSYMBOL_LIST = "、。・゛゜´｀¨ヽヾゝゞ〃仝々〆〇ー―‐＼～〜∥…‥“〔〕〈〉《》「」『』【】" \
                     "±×÷≠≦≧∞∴♂♀°′″℃￠￡§☆★○●◎◇◇◆□■△▲▽▼※〒→←↑↓〓"

  HAN_KATA_LIST = "ﾊﾋﾌﾍﾎｳｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄｱｲｴｵﾅﾆﾇﾈﾉﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝｧｨｩｪｫｬｭｮｯ"
  ZEN_KATA_SEION_LIST = "ハヒフヘホウカキクケコサシスセソタチツテトアイエオ" \
                        "ナニヌネノマミムメモヤユヨラリルレロワヲンァィゥェォャュョッ"
  # 濁音表は HAN_KATA_LIST の先頭 21 文字に対応する。ヴ も濁音として ｳﾞ に対応する。
  ZEN_KATA_DAKUON_LIST = "バビブベボヴガギグゲゴザジズゼゾダヂヅデド"
  # 半濁音表は HAN_KATA_LIST の先頭 5 文字（ﾊﾋﾌﾍﾎ）に対応する。
  ZEN_KATA_HANDAKUON_LIST = "パピプペポ"

  # 清音・濁音・半濁音の 3 本組（lib 側 ZEN_KATA_LISTS と同じ並び）。
  ZEN_KATA_LISTS = [ZEN_KATA_SEION_LIST, ZEN_KATA_DAKUON_LIST, ZEN_KATA_HANDAKUON_LIST].freeze

  # ---- 以下は正データからの導出（各テストが従来リテラルで持っていた構造） ----
  # 導出（chars / zip / 文字列補間）が生む文字列は frozen_string_literal の対象外で
  # 非凍結になるため、要素文字列まで明示的に凍結する。全テストファイルが 1 プロセスで
  # 共有する期待値なので、破壊的変更による汚染を旧リテラル同様 FrozenError で即検知する。

  # 全角カタカナ → 半角カタカナの全対応表。
  # 濁音は「半角カナ + ﾞ」、半濁音は「半角カナ + ﾟ」の 2 文字に分解される。
  ZEN_TO_HAN_KATA_PAIRS = (
    ZEN_KATA_SEION_LIST.chars.zip(HAN_KATA_LIST.chars) +
    ZEN_KATA_DAKUON_LIST.chars.zip(HAN_KATA_LIST.chars.map { |h| "#{h}ﾞ" }) +
    ZEN_KATA_HANDAKUON_LIST.chars.zip(HAN_KATA_LIST.chars.map { |h| "#{h}ﾟ" })
  ).each { |pair| pair.each(&:freeze) }.freeze

  # ZEN_ASYMBOL_LIST → HAN_ASYMBOL_LIST の 1:1 対応。
  ZEN_TO_HAN_ASYMBOL_PAIRS =
    ZEN_ASYMBOL_LIST.chars.zip(HAN_ASYMBOL_LIST.chars)
                    .each { |pair| pair.each(&:freeze) }.freeze

  # ZEN_JSYMBOL1_LIST → HAN_JSYMBOL1_LIST の対応。
  ZEN_TO_HAN_JSYMBOL1_PAIRS =
    ZEN_JSYMBOL1_LIST.chars.zip(HAN_JSYMBOL1_LIST.chars)
                     .each { |pair| pair.each(&:freeze) }.freeze

  # ZEN_JSYMBOL_LIST に含まれるが JSYMBOL1 の対応表に無い文字（＝変換されない）。
  ZEN_JSYMBOL_UNCONVERTED_CHARS =
    (ZEN_JSYMBOL_LIST.chars.uniq - ZEN_JSYMBOL1_LIST.chars).each(&:freeze).freeze
end

# 複数のテストファイルで共有するヘルパー。
module MojiTestHelpers
  private

  # Encoding.default_internal を一時的に設定する。
  # 設定時の警告を抑えるため $VERBOSE も落とし、どちらも ensure で必ず復元する。
  def with_default_internal(encoding)
    orig_internal = Encoding.default_internal
    orig_verbose = $VERBOSE
    $VERBOSE = nil
    Encoding.default_internal = encoding
    yield
  ensure
    Encoding.default_internal = orig_internal
    $VERBOSE = orig_verbose
  end
end

# rake test は Rake::TestTask の warning 既定(-w 相当)で Warning[:deprecated] が
# true になり、非 UTF-8 のゴールデンテスト実行中に deprecation 警告が stderr へ
# 多数混ざる。警告そのものの検証は test_deprecation.rb が capture 内で明示的に
# 有効化して行うため、既定の実行では抑止して進捗表示を読めるように保つ。
Warning[:deprecated] = false
