# frozen_string_literal: true

# このファイルの文字コードは UTF-8 です。
# 「〜」(U+301C) と「～」(U+FF5E) の書き分けを含む変換テーブルをリテラルに持つため、
# エンコーディング変換や Unicode 正規化を行うツールを通してはいけません。

module Moji
  # 変換テーブルとエンコーディング処理の実装詳細。外部からの利用は想定しない。
  # @api private
  module Detail
    HAN_ASYMBOL_LIST = ' !"#$%&\'()*+,-./:;<=>?@[\]^_`{|}~'
    ZEN_ASYMBOL_LIST = "　！”＃＄％＆’（）＊＋，－．／：；＜＝＞？＠［￥］＾＿‘｛｜｝￣"
    HAN_JSYMBOL1_LIST = "｡｢｣､ｰﾞﾟ･"
    ZEN_JSYMBOL1_LIST = "。「」、ー゛゜・"
    ZEN_JSYMBOL_LIST = "、。・゛゜´｀¨ヽヾゝゞ〃仝々〆〇ー―‐＼～〜∥…‥“〔〕〈〉《》「」『』【】" \
                       "±×÷≠≦≧∞∴♂♀°′″℃￠￡§☆★○●◎◇◇◆□■△▲▽▼※〒→←↑↓〓"
    # tr 用にメタ文字(- ^ \)をエスケープした ASCII 記号リスト。
    # 正規表現の文字クラス用(CHAR_REGEXPS 側)とはエスケープ対象の文字集合が異なる。
    HAN_ASYMBOL_TR_LIST = HAN_ASYMBOL_LIST.gsub(/[-\^\\]/) { "\\#{$&}" }
    HAN_KATA_LIST = "ﾊﾋﾌﾍﾎｳｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄｱｲｴｵﾅﾆﾇﾈﾉﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜｦﾝｧｨｩｪｫｬｭｮｯ".chars
    HAN_VSYMBOLS = ["", "ﾞ", "ﾟ"].freeze
    ZEN_KATA_LISTS = [
      "ハヒフヘホウカキクケコサシスセソタチツテトアイエオ" \
      "ナニヌネノマミムメモヤユヨラリルレロワヲンァィゥェォャュョッ",
      "バビブベボヴガギグゲゴザジズゼゾダヂヅデド",
      "パピプペポ",
    ].map(&:chars)

    # Moji.regexp の合成結果のメモ化。キーは [文字種の整数値, 解決後エンコーディング]。
    # 解決後エンコーディングをキーに含めるため、Encoding.default_internal の
    # 実行時変更にも正しく追随する。一方 CHAR_REGEXPS の実行時差し替えには
    # 追随しない(キャッシュ済みの合成結果を返し続ける)。
    # 任意の | 合成もキーになりうるため、エントリ数に上限を設けて超過分は
    # メモ化せず都度合成する(メモリを有界に保つ)。
    REGEXP_CACHE = {} # rubocop:disable Style/MutableConstant -- キャッシュとして書き込む
    REGEXP_CACHE_LIMIT = 100

    # 入力を UTF-8 に正規化してブロックを評価し、結果が文字列なら
    # 元エンコーディングへ戻して返す。
    #
    # @param str [String] 入力文字列
    # @yieldparam utf8_str [String] UTF-8 化した入力
    # @return [Object] ブロックの評価結果(文字列なら元エンコーディングへ変換済み)
    def self.convert_encoding(str)
      orig_enc = str.encoding
      if orig_enc == Encoding::UTF_8
        # 無駄なコピーを避けるためにencodeを呼ばない。
        yield(str)
      else
        result = yield(str.encode(Encoding::UTF_8))
        result.is_a?(String) ? result.encode(orig_enc) : result
      end
    end
  end
end
