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

    # zen_to_han のカタカナ変換対象(全角カタカナ 81 文字)の 1 文字にマッチする
    # 正規表現。従来は呼び出しごとに構築していたが、内容は定数なので巻き上げる。
    ZEN_KATA_REGEXP = Regexp.new(format("[%s]", ZEN_KATA_LISTS.join))

    # 全角カタカナ → 半角カタカナの変換表。従来の gsub ブロックの走査ロジック
    # (ZEN_KATA_LISTS をリスト順に探して最初に見つかった対応を採る)をそのまま
    # 実行して構築するため、先勝ちのセマンティクスは ||= で保存される。
    ZEN_TO_HAN_KATA_TABLE = {} # rubocop:disable Style/MutableConstant -- 直後に構築して freeze する
    ZEN_KATA_LISTS.each_with_index do |list, i|
      list.each_with_index do |zen, pos|
        ZEN_TO_HAN_KATA_TABLE[zen] ||= HAN_KATA_LIST[pos] + HAN_VSYMBOLS[i]
      end
    end
    ZEN_TO_HAN_KATA_TABLE.freeze

    # 半角カナ(+半角濁点/半濁点 0〜1 個) → 全角カナの変換表。従来の gsub
    # ブロックのロジック(HAN_KATA_LIST の Array#index による先勝ち・濁音表に
    # 対応が無い組は清音 + 記号のまま)をそのまま実行して構築する。
    # キーは han_to_zen のカナ用正規表現がマッチしうる全 165 通り
    # (半角カナ 55 × 記号 3 種)を網羅する。
    HAN_TO_ZEN_KATA_TABLE = {} # rubocop:disable Style/MutableConstant -- 直後に構築して freeze する
    HAN_KATA_LIST.each_with_index do |han, pos|
      HAN_VSYMBOLS.each_with_index do |mark, i|
        zen = ZEN_KATA_LISTS[i][pos]
        HAN_TO_ZEN_KATA_TABLE[han + mark] ||= !zen || zen == "" ? ZEN_KATA_LISTS[0][pos] + mark : zen
      end
    end
    HAN_TO_ZEN_KATA_TABLE.freeze

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
