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

    # Moji.regexp の合成結果のメモ化。キーは [文字種(Flags), 解決後エンコーディング]。
    # 解決後エンコーディングをキーに含めるため、Encoding.default_internal の
    # 実行時変更にも正しく追随する。一方 CHAR_REGEXPS は各キーの初回呼び出し
    # 時点の内容で固定され、以後の差し替え(元に戻す変更を含む)には追随しない。
    # 任意の | 合成もキーになりうるため、エントリ数に上限を設けて超過分は
    # メモ化せず都度合成する(メモリを有界に保つ)。
    REGEXP_CACHE = {} # rubocop:disable Style/MutableConstant -- キャッシュとして書き込む
    REGEXP_CACHE_LIMIT = 100

    # han_to_zen のカナ用合成正規表現(半角カナ 1 文字 + 濁点/半濁点 0〜1 個)の
    # メモ化。キーは解決後エンコーディング(取りうる値が有限なので上限は設けない)。
    # 合成が RegexpError になるエンコーディングはメモ化されない(han_to_zen 側の
    # コメントを参照)。
    HAN_TO_ZEN_KATA_REGEXPS = {} # rubocop:disable Style/MutableConstant -- キャッシュとして書き込む

    # Moji.type 用のコードポイント範囲表。[先頭, 末尾, 基本文字種の定数名]。
    # CHAR_REGEXPS の挿入順走査(最初にマッチした文字種が勝つ)を BMP 全域で
    # 実行した結果から連続範囲を合体して生成したもので、走査順依存の判定も
    # 範囲の形にそのまま現れている(例: 仝 U+4EDD は ZEN_KANJI の範囲内だが
    # ZEN_JSYMBOL が先に取るため単独範囲として分離される)。
    # CHAR_REGEXPS を実行時に差し替えてもこの表には反映されない。
    # 再生成するときは CHAR_REGEXPS の replay で作り直すこと。ロード時の
    # CHAR_REGEXPS との一致はテスト(test_type.rb の BMP 全数突合)が機械検証する。
    TYPE_RANGE_DATA = [
      [0x0000, 0x001F, :HAN_CONTROL],
      [0x0020, 0x002F, :HAN_ASYMBOL],
      [0x0030, 0x0039, :HAN_NUMBER],
      [0x003A, 0x0040, :HAN_ASYMBOL],
      [0x0041, 0x005A, :HAN_UPPER],
      [0x005B, 0x0060, :HAN_ASYMBOL],
      [0x0061, 0x007A, :HAN_LOWER],
      [0x007B, 0x007E, :HAN_ASYMBOL],
      [0x007F, 0x007F, :HAN_CONTROL],
      [0x00A7, 0x00A8, :ZEN_JSYMBOL],
      [0x00B0, 0x00B1, :ZEN_JSYMBOL],
      [0x00B4, 0x00B4, :ZEN_JSYMBOL],
      [0x00D7, 0x00D7, :ZEN_JSYMBOL],
      [0x00F7, 0x00F7, :ZEN_JSYMBOL],
      [0x0391, 0x03A9, :ZEN_GREEK],
      [0x03B1, 0x03C9, :ZEN_GREEK],
      [0x0410, 0x044F, :ZEN_CYRILLIC],
      [0x2010, 0x2010, :ZEN_JSYMBOL],
      [0x2015, 0x2015, :ZEN_JSYMBOL],
      [0x2018, 0x2019, :ZEN_ASYMBOL],
      [0x201C, 0x201C, :ZEN_JSYMBOL],
      [0x201D, 0x201D, :ZEN_ASYMBOL],
      [0x2025, 0x2026, :ZEN_JSYMBOL],
      [0x2032, 0x2033, :ZEN_JSYMBOL],
      [0x203B, 0x203B, :ZEN_JSYMBOL],
      [0x2103, 0x2103, :ZEN_JSYMBOL],
      [0x2190, 0x2193, :ZEN_JSYMBOL],
      [0x221E, 0x221E, :ZEN_JSYMBOL],
      [0x2225, 0x2225, :ZEN_JSYMBOL],
      [0x2234, 0x2234, :ZEN_JSYMBOL],
      [0x2260, 0x2260, :ZEN_JSYMBOL],
      [0x2266, 0x2267, :ZEN_JSYMBOL],
      [0x2570, 0x259F, :ZEN_LINE],
      [0x25A0, 0x25A1, :ZEN_JSYMBOL],
      [0x25A2, 0x25B1, :ZEN_LINE],
      [0x25B2, 0x25B3, :ZEN_JSYMBOL],
      [0x25B4, 0x25BB, :ZEN_LINE],
      [0x25BC, 0x25BD, :ZEN_JSYMBOL],
      [0x25BE, 0x25C5, :ZEN_LINE],
      [0x25C6, 0x25C7, :ZEN_JSYMBOL],
      [0x25C8, 0x25CA, :ZEN_LINE],
      [0x25CB, 0x25CB, :ZEN_JSYMBOL],
      [0x25CC, 0x25CD, :ZEN_LINE],
      [0x25CE, 0x25CF, :ZEN_JSYMBOL],
      [0x25D0, 0x25FF, :ZEN_LINE],
      [0x2605, 0x2606, :ZEN_JSYMBOL],
      [0x2640, 0x2640, :ZEN_JSYMBOL],
      [0x2642, 0x2642, :ZEN_JSYMBOL],
      [0x3000, 0x3000, :ZEN_ASYMBOL],
      [0x3001, 0x3003, :ZEN_JSYMBOL],
      [0x3005, 0x3015, :ZEN_JSYMBOL],
      [0x301C, 0x301C, :ZEN_JSYMBOL],
      [0x3041, 0x3093, :ZEN_HIRA],
      [0x309B, 0x309E, :ZEN_JSYMBOL],
      [0x30A1, 0x30F6, :ZEN_KATA],
      [0x30FB, 0x30FE, :ZEN_JSYMBOL],
      [0x3400, 0x4DBF, :ZEN_KANJI],
      [0x4E00, 0x4EDC, :ZEN_KANJI],
      [0x4EDD, 0x4EDD, :ZEN_JSYMBOL],
      [0x4EDE, 0x9FFF, :ZEN_KANJI],
      [0xF900, 0xFAFF, :ZEN_KANJI],
      [0xFF01, 0xFF01, :ZEN_ASYMBOL],
      [0xFF03, 0xFF06, :ZEN_ASYMBOL],
      [0xFF08, 0xFF0F, :ZEN_ASYMBOL],
      [0xFF10, 0xFF19, :ZEN_NUMBER],
      [0xFF1A, 0xFF20, :ZEN_ASYMBOL],
      [0xFF21, 0xFF3A, :ZEN_UPPER],
      [0xFF3B, 0xFF3B, :ZEN_ASYMBOL],
      [0xFF3C, 0xFF3C, :ZEN_JSYMBOL],
      [0xFF3D, 0xFF3F, :ZEN_ASYMBOL],
      [0xFF40, 0xFF40, :ZEN_JSYMBOL],
      [0xFF41, 0xFF5A, :ZEN_LOWER],
      [0xFF5B, 0xFF5D, :ZEN_ASYMBOL],
      [0xFF5E, 0xFF5E, :ZEN_JSYMBOL],
      [0xFF61, 0xFF65, :HAN_JSYMBOL],
      [0xFF66, 0xFF6F, :HAN_KATA],
      [0xFF70, 0xFF70, :HAN_JSYMBOL],
      [0xFF71, 0xFF9D, :HAN_KATA],
      [0xFF9E, 0xFF9F, :HAN_JSYMBOL],
      [0xFFE0, 0xFFE1, :ZEN_JSYMBOL],
      [0xFFE3, 0xFFE3, :ZEN_ASYMBOL],
      [0xFFE5, 0xFFE5, :ZEN_ASYMBOL],
    ].freeze

    # 入力を UTF-8 に正規化してブロックを評価し、結果が文字列なら
    # 元エンコーディングへ戻して返す。
    #
    # nfc を有効にすると、UTF-8 化した入力とブロックの文字列結果の両方へ
    # NFC 正規化を適用する。出力側の適用は省略できない: han_to_zen の
    # カナ用正規表現は半角の濁点記号(U+FF9E/FF9F)しか拾わないため、
    # 「半角カナ + 結合濁点(U+3099)」の入力からは NFC でない中間列
    # (全角カナ + U+3099)が生じ、これを合成するのは出口の NFC だけである。
    #
    # @param str [String] 入力文字列
    # @param nfc [Boolean] 入力と文字列結果を NFC 正規化するか
    # @yieldparam utf8_str [String] UTF-8 化した入力
    # @return [Object] ブロックの評価結果(文字列なら元エンコーディングへ変換済み)
    def self.convert_encoding(str, nfc: false)
      orig_enc = str.encoding
      if orig_enc == Encoding::UTF_8 && !nfc
        # 無駄なコピーを避けるためにencodeを呼ばない。
        return yield(str)
      end

      utf8 = orig_enc == Encoding::UTF_8 ? str : str.encode(Encoding::UTF_8)
      utf8 = utf8.unicode_normalize(:nfc) if nfc
      result = yield(utf8)
      return result unless result.is_a?(String)

      result = result.unicode_normalize(:nfc) if nfc
      orig_enc == Encoding::UTF_8 ? result : result.encode(orig_enc)
    end
  end
end
