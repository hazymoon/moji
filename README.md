# moji

日本語の文字種判定、文字種変換(半角→全角、ひらがな→カタカナなど)を行う Ruby ライブラリです。

[gimite/moji](https://github.com/gimite/moji) 1.6 の fork で、公開 API と変換・判定結果の互換性を基本方針として Ruby 3.3 以降に対応しています(v2.1 でフラグ系の既知バグのみ修正。[#3](https://github.com/hazymoon/moji/issues/3))。

> **English**: moji is a Ruby library for Japanese character type classification and conversion (half-width ↔ full-width, hiragana ↔ katakana, upper ↔ lower case). This is a fork of [gimite/moji](https://github.com/gimite/moji) 1.6, modernized for Ruby 3.3+ while keeping API and behavioral compatibility, except for an agreed flag-handling bug fix in v2.1 ([#3](https://github.com/hazymoon/moji/issues/3)).

## 対応環境

Ruby 3.3 以降。

## インストール

RubyGems.org では配布していません。Gemfile に git ソースで指定してください。

```ruby
gem "moji", github: "hazymoon/moji"
```

上記は既定ブランチ追従のため、`bundle update` でリリースを跨いで挙動が変わりえます(たとえば v2.1.0 は [#3](https://github.com/hazymoon/moji/issues/3) のフラグ系バグ修正を含みます。「[本家との差異](#本家との差異)」参照)。更新のタイミングを自分で決めたい場合は `tag:` でバージョンを固定してください。

```ruby
gem "moji", github: "hazymoon/moji", tag: "v2.1.0"
```

## 使い方

どのエンコーディングの文字列を渡しても動作しますが、`String#encoding` が正しく設定されている必要があります。正規表現を返す関数(`Moji.kata` など)は `Encoding.default_internal`(未設定の場合は UTF-8)用の正規表現を返します。その他のエンコーディング用の正規表現は `Moji.kata(Encoding::SJIS)` などで取得できます(文字種依存の制限あり。「[既知の制限](#既知の制限)」参照)。

> **非推奨**: 非 UTF-8 文字列の入力と、正規表現系関数の非 UTF-8 エンコーディング(encoding 引数・`Encoding.default_internal` 由来とも)は v2.1 で deprecated となり、v3.0 で削除予定です([#5](https://github.com/hazymoon/moji/issues/5))。該当経路は `category: :deprecated` の警告を出します(表示には `Warning[:deprecated] = true` または `ruby -W:deprecated` が必要)。`Moji.encodable?` / `Moji.unencodable` は判定系のため対象外です(encoding 引数と `Moji.encodable?` への非 UTF-8 文字列入力を含めて v3.0 でも受け付けます)。US-ASCII は UTF-8 の部分集合のため対象外です(v3.0 でも受け付けます)。

```ruby
require "moji"

# 文字種判定。
Moji.type("漢")                                    # => Moji::ZEN_KANJI
Moji.type?("Ａ", Moji::ZEN)                        # => true

# 文字種変換。
Moji.zen_to_han("Ｒｕｂｙ")                        # => "Ruby"
Moji.upcase("Ｒｕｂｙ")                            # => "ＲＵＢＹ"
Moji.kata_to_hira("ルビー")                        # => "るびー"

# 文字種による正規表現。
/#{Moji.kata}+#{Moji.hira}+/ =~ "ぼくドラえもん"   # => 2
Regexp.last_match.to_s                             # => "ドラえもん"
```

## 定数

以下の定数は、文字種の一番細かい分類です。`Moji.type` が返すのは、以下の定数のうちの 1 つです。

| 定数 | 説明 |
| --- | --- |
| `HAN_CONTROL` | 制御文字 |
| `HAN_ASYMBOL` | ASCII に含まれる半角記号 |
| `HAN_JSYMBOL` | JIS に含まれるが ASCII には含まれない半角記号 |
| `HAN_NUMBER` | 半角数字 |
| `HAN_UPPER` | 半角アルファベット大文字 |
| `HAN_LOWER` | 半角アルファベット小文字 |
| `HAN_KATA` | 半角カタカナ |
| `ZEN_ASYMBOL` | JIS の全角記号のうち、ASCII に対応する半角記号があるもの |
| `ZEN_JSYMBOL` | JIS の全角記号のうち、ASCII に対応する半角記号がないもの |
| `ZEN_NUMBER` | 全角数字 |
| `ZEN_UPPER` | 全角アルファベット大文字 |
| `ZEN_LOWER` | 全角アルファベット小文字 |
| `ZEN_HIRA` | ひらがな |
| `ZEN_KATA` | 全角カタカナ |
| `ZEN_GREEK` | ギリシャ文字 |
| `ZEN_CYRILLIC` | キリル文字 |
| `ZEN_LINE` | 罫線のかけら |
| `ZEN_KANJI` | 漢字 |

以下の定数は、上の文字種の組み合わせと別名です。

| 定数 | 説明 | 定義 |
| --- | --- | --- |
| `HAN_SYMBOL` | JIS に含まれる半角記号 | `HAN_ASYMBOL \| HAN_JSYMBOL` |
| `HAN_ALPHA` | 半角アルファベット | `HAN_UPPER \| HAN_LOWER` |
| `HAN_ALNUM` | 半角英数字 | `HAN_ALPHA \| HAN_NUMBER` |
| `HAN` | 全ての半角文字 | `HAN_CONTROL \| HAN_SYMBOL \| HAN_ALNUM \| HAN_KATA` |
| `ZEN_SYMBOL` | JIS に含まれる全角記号 | `ZEN_ASYMBOL \| ZEN_JSYMBOL` |
| `ZEN_ALPHA` | 全角アルファベット | `ZEN_UPPER \| ZEN_LOWER` |
| `ZEN_ALNUM` | 全角英数字 | `ZEN_ALPHA \| ZEN_NUMBER` |
| `ZEN_KANA` | 全角かな/カナ | `ZEN_KATA \| ZEN_HIRA` |
| `ZEN` | JIS に含まれる全ての全角文字 | `ZEN_SYMBOL \| ZEN_ALNUM \| ZEN_KANA \| ZEN_GREEK \| ZEN_CYRILLIC \| ZEN_LINE \| ZEN_KANJI` |
| `ASYMBOL` | ASCII に含まれる半角記号とその全角版 | `HAN_ASYMBOL \| ZEN_ASYMBOL` |
| `JSYMBOL` | JIS に含まれるが `ASYMBOL` には含まれない全角/半角記号 | `HAN_JSYMBOL \| ZEN_JSYMBOL` |
| `SYMBOL` | JIS に含まれる全ての全角/半角記号 | `HAN_SYMBOL \| ZEN_SYMBOL` |
| `NUMBER` | 全角/半角数字 | `HAN_NUMBER \| ZEN_NUMBER` |
| `UPPER` | 全角/半角アルファベット大文字 | `HAN_UPPER \| ZEN_UPPER` |
| `LOWER` | 全角/半角アルファベット小文字 | `HAN_LOWER \| ZEN_LOWER` |
| `ALPHA` | 全角/半角アルファベット | `HAN_ALPHA \| ZEN_ALPHA` |
| `ALNUM` | 全角/半角英数字 | `HAN_ALNUM \| ZEN_ALNUM` |
| `HIRA` | `ZEN_HIRA` の別名 | |
| `KATA` | 全角/半角カタカナ | `HAN_KATA \| ZEN_KATA` |
| `KANA` | 全角/半角 かな/カナ | `KATA \| ZEN_HIRA` |
| `GREEK` | `ZEN_GREEK` の別名 | |
| `CYRILLIC` | `ZEN_CYRILLIC` の別名 | |
| `LINE` | `ZEN_LINE` の別名 | |
| `KANJI` | `ZEN_KANJI` の別名 | |
| `ALL` | 上記全ての文字 | `HAN \| ZEN` |

## モジュール関数

文字列を受ける関数(`Moji.regexp` と正規表現メソッドを除くすべて)は、v2.1 で追加された `nfc:` キーワード引数(既定 false)を持ちます。有効にすると入力と結果を NFC 正規化します(挙動の詳細と副作用は「[既知の制限](#既知の制限)」の結合文字の項を参照)。

### `Moji.type(ch)`

文字 `ch` の文字種を返します。「一番細かい分類」の定数のうち 1 つを返します。

上の分類に当てはまらない文字(Unicode のハングルなど)に対しては `nil` を返します。また、Unicode の BMP 外の文字に対しても `nil` を返します。文字が割り当てられていない文字コードに対する結果は不定です(`nil` を返す事もあります)。

```ruby
Moji.type("漢")   # => Moji::ZEN_KANJI
```

### `Moji.type?(ch, type)`

文字 `ch` が文字種 `type` に含まれれば `true` を返します。`type` には全ての定数と、それらを `|` で結んだものを使えます。`Moji.type` が `nil` を返す文字(ハングル・絵文字・BMP 外など判定不能な文字)と空文字列には、どの文字種を渡しても `false` を返します(v2.0 系までは本家 1.6 のバグを維持して常に `true` でした。[#3](https://github.com/hazymoon/moji/issues/3))。

v2.0 系で「日本語の文字種に含まれるか」のバリデーションを行う場合は、従来どおり `Moji.type` の `nil` 判定か正規表現を使ってください。この回避策は v2.1 以降でも同じ結果を返すため、移行時にそのまま残して問題ありません。

```ruby
Moji.type?("Ａ", Moji::ZEN)   # => true
Moji.type?("한", Moji::ZEN)   # => false (v2.0 系までは true)
```

### `Moji.regexp(type[, encoding])`

文字種 `type` の 1 文字を表す正規表現を返します。`type` には全ての定数と、それらを `|` で結んだものを使えます。

`encoding` に `Encoding` オブジェクトを渡すと、その文字種の正規表現を指定のエンコーディングへ変換して返します。省略すると `Encoding.default_internal`(未設定の場合は `Encoding::UTF_8`)とみなします。

ただし変換できるのは文字種の全文字が対象エンコーディングに存在する場合だけで、以下の制限があります([#5](https://github.com/hazymoon/moji/issues/5))。

- `ALL` / `ZEN` / `ZEN_JSYMBOL` など「〜」(U+301C)と「～」(U+FF5E)の両方を含む文字種は、Shift_JIS / Windows-31J / EUC-JP のいずれを渡しても `Encoding::UndefinedConversionError` になります
- ASCII のみで定義された文字種(`HAN_NUMBER` / `HAN_UPPER` など)は `encoding` 引数が無視され US-ASCII の正規表現が返ります
- `ZEN_KANJI` / `ZEN_LINE` は内部が `\uXXXX` エスケープのため `encoding` 引数が無視され、常に UTF-8 の正規表現が返ります
- `Encoding::SJIS` は Ruby では Windows-31J の別名です。`Moji.regexp(type, Encoding::SJIS)` が返す正規表現は Windows-31J であり、厳密な Shift_JIS とは変換可否が分かれる文字(全角ハイフン「－」など)があります

```ruby
Moji.regexp(Moji::HIRA)   # => /[ぁ-ん]/
```

### `Moji.zen_to_han(str[, type])`

文字列 `str` の全角を半角に変換して返します。`type` には、変換対象とする文字種を定数で指定します。デフォルトは `ALL`(全て)です。

```ruby
Moji.zen_to_han("Ｒｕｂｙ！？")                # => "Ruby!?"
Moji.zen_to_han("Ｒｕｂｙ！？", Moji::ALPHA)   # => "Ruby！？"
```

### `Moji.han_to_zen(str[, type])`

文字列 `str` の半角を全角に変換して返します。`type` には、変換対象とする文字種を定数で指定します。デフォルトは `ALL`(全て)です。

```ruby
Moji.han_to_zen("Ruby!?")                 # => "Ｒｕｂｙ！？"
Moji.han_to_zen("Ruby!?", Moji::SYMBOL)   # => "Ruby！？"
```

非 UTF-8 入力では、変換結果を入力のエンコーディングへ戻せない場合に `Encoding::UndefinedConversionError` になります([#5](https://github.com/hazymoon/moji/issues/5))。代表例はハイフンで、`-` の全角化結果「－」(U+FF0D)は Shift_JIS(厳密)・EUC-JP に存在しないため、これらのエンコーディングの入力に変換対象の `-` が 1 文字でも含まれると例外になります(Windows-31J は U+FF0D を持つため成功します)。US-ASCII 入力も同じ理由で、変換対象の文字が 1 文字でもあれば例外になります(全角化の結果は必ず非 ASCII になるため)。

### `Moji.normalize_zen_han(str)`

文字列 `str` の全角、半角を一般的なものに統一します。具体的には、ASCII に含まれる記号と英数字(`ALNUM | ASYMBOL`)を半角に、それ以外の記号とカタカナ(`JSYMBOL | HAN_KATA`)を全角に変換します。

### `Moji.upcase(str[, type])`

文字列 `str` の小文字を大文字に変換して返します。`type` には、変換対象とする文字種を定数で指定します。デフォルトは `LOWER`(全角/半角のアルファベット)です。ギリシャ文字、キリル文字には対応していません。

```ruby
Moji.upcase("Ｒｕｂｙ")   # => "ＲＵＢＹ"
```

### `Moji.downcase(str[, type])`

文字列 `str` の大文字を小文字に変換して返します。`type` には、変換対象とする文字種を定数で指定します。デフォルトは `UPPER`(全角/半角のアルファベット)です。ギリシャ文字、キリル文字には対応していません。

```ruby
Moji.downcase("Ｒｕｂｙ")   # => "ｒｕｂｙ"
```

### `Moji.kata_to_hira(str)`

文字列 `str` の全角カタカナをひらがなに変換して返します。半角カタカナは直接変換できません。`han_to_zen` で全角にしてから変換してください。

```ruby
Moji.kata_to_hira("ルビー")   # => "るびー"
```

### `Moji.hira_to_kata(str)`

文字列 `str` のひらがなを全角カタカナに変換して返します。

```ruby
Moji.hira_to_kata("るびー")   # => "ルビー"
```

### `Moji.han_control([encoding])` ほか正規表現メソッド

定数それぞれに対応するメソッド(`Moji.han_control`、`Moji.han_asymbol`、…、`Moji.kana`、…)があり、それぞれの文字種の 1 文字を表す正規表現を返します。例えば `Moji.kana` は `Moji.regexp(Moji::KANA)` と同じです。

`encoding` に `Encoding` オブジェクトを渡すと、指定のエンコーディング用の正規表現を返します(`Moji.regexp` と同じ制限があります)。省略すると `Encoding.default_internal`(未設定の場合は `Encoding::UTF_8`)とみなします。

以下の例のように、文字クラスっぽく使えます。

```ruby
/#{Moji.kata}+#{Moji.hira}+/ =~ "ぼくドラえもん"   # => 2
Regexp.last_match.to_s                             # => "ドラえもん"
```

## 符号化可否の判定

v2.1 で追加([#14](https://github.com/hazymoon/moji/issues/14))。文字列がレガシーエンコーディングへ無損失に符号化できるかを判定します。判定の定義は「Ruby の当該エンコーディングへ `String#encode` で変換できるか」で、範囲表は Ruby 3.3 の変換表から生成しています(`tools/gen_encodable_tables.rb`)。符号化の成功は往復の同一性までは保証しません(例: ―(U+2015)は Shift_JIS / EUC-JIS-2004 で —(U+2014)と同一バイト列に写るため、復号すると U+2014 になります)。

対応エンコーディングは 3 種で、それぞれ実務上の使い分けに対応します。3 集合は包含関係にありません(髙 は Windows-31J のみ、𠮟 は EUC-JIS-2004 のみ)。

| エンコーディング | 実務上の意味 |
| --- | --- |
| `Shift_JIS`(厳密) | JIS X 0201 + 0208 のみ。ベンダー拡張を認めない最厳格ライン(髙・① を弾く) |
| `Windows-31J`(CP932) | Windows の帳票・CSV・Excel の現実ライン(NEC 特殊文字・IBM 拡張漢字を含む) |
| `EUC-JIS-2004` | JIS X 0213:2004(第 3・第 4 水準)。常用漢字の 𠮟(BMP 外)を含む現代 JIS の完全ライン |

### `Moji.encodable?(str, encoding[, nfc:])`

文字列 `str` の全文字が `encoding` へ符号化可能なら `true` を返します(空文字列は `true`)。`encoding` は `Encoding` オブジェクトか名前文字列で、対応外は `ArgumentError` です。`Encoding::SJIS` は Ruby の別名解決に従い Windows-31J として扱われます。NFD のかな(結合濁点)はどのレガシーエンコーディングにも属さないため、NFD が混入しうる入力では `nfc: true` の併用を推奨します。

```ruby
Moji.encodable?("髙橋", Encoding::Windows_31J)   # => true
Moji.encodable?("髙橋", Encoding::Shift_JIS)     # => false (髙 は IBM 拡張)
Moji.encodable?("𠮟る", "EUC-JIS-2004")          # => true
```

### `Moji.unencodable(encoding)`

`encoding` へ符号化できない 1 文字にマッチする正規表現を返します。`scan` での洗い出しや `gsub` での置換に使えます。返る正規表現は UTF-8 なので、判定対象の文字列も UTF-8 にしてからマッチしてください(非 UTF-8 文字列とのマッチは `Encoding::CompatibilityError` になります)。また、正規表現は入力を正規化できないため、NFD が混入しうる入力は事前に NFC 正規化してからマッチしてください(NFD のかなをそのまま `gsub` すると結合濁点だけが置換され、`encodable?` の `nfc: true` の判定とも食い違います)。

```ruby
"髙橋①".scan(Moji.unencodable(Encoding::Shift_JIS))   # => ["髙", "①"]
```

## 既知の制限

本家 1.6 互換の方針により、以下の挙動を意図的に維持しています(フラグ系のバグは v2.1 で修正済み。[#3](https://github.com/hazymoon/moji/issues/3))。改善の計画は「[ロードマップ](#ロードマップ)」の節と GitHub の [milestones](https://github.com/hazymoon/moji/milestones) を参照してください。

- **文字列はコードポイント単位で処理されます**([#1](https://github.com/hazymoon/moji/issues/1))。結合文字列(NFD 形式のかな・結合アクセント・異体字セレクタ)は基底文字だけが変換・マッチの対象になります。特に NFD の全角カナを `zen_to_han` すると「半角カナ + 結合濁点」という CP932 等へ変換できない列が生じ、後段の `encode` で初めて失敗します。NFD が混入しうる入力(HFS+ 由来のファイル名・ZIP・macOS からのアップロード等)は、v2.1 で追加された `nfc: true` キーワード引数(文字列を受ける全関数で利用可)を渡すか、呼び出し前に `unicode_normalize(:nfc)` してください(NFKC は全角・半角の区別ごと潰すため使わないでください)。`nfc: true` は入力と結果の両方を NFC 正規化します(結果が文字列でない `type` / `type?` は入力のみ)。ただし入力が既に「半角カナ + 結合濁点」の場合の `zen_to_han` は `nfc: true` でも救えません(この組は NFC で合成されないため。`han_to_zen` / `normalize_zen_han` を経由すれば合成済みの全角へ畳めます)。また NFC 自体の副作用があります: (1) CJK 互換漢字が標準字体へ置換されます(神 U+FA19 → 神 U+795E など。Windows-31J の IBM 拡張に 22 字(U+FA10〜U+FA2D の 20 字と U+F929(朗)・U+F9DC(隆))が該当し、人名の字体が静かに変わりえます) (2) Å(U+212B)・凞(U+FA15)・蘒(U+FA20)は合成後のコードポイントを Windows-31J へ戻せないため、これらを含む非 UTF-8 入力では既定なら成功する変換が `Encoding::UndefinedConversionError` になります (3) e + 結合アクセントのような分解列は入口で合成され、`upcase` / `downcase` の大文字小文字変換や `han_to_zen` の全角化の対象から外れます (4) `ｦﾞ`(半角ヲ + 半角濁点)の全角化結果は本家由来のフォールバックで「ヲ + 非結合の濁点記号」になるため NFC でも合成されません (5) 「う・ワ行 + 結合濁点」は ゔ(U+3094)・ヷヸヹヺ(U+30F7〜U+30FA)へ合成されますが、これらは本家由来の判定・変換範囲([#4](https://github.com/hazymoon/moji/issues/4))の外のため、既定なら基底文字で判定・変換されていたものが、`type` / `type?` では `nil` / false へ変わり、`kata_to_hira` / `hira_to_kata` / `zen_to_han` では変換されずに残ります(合成先のうち ヷヸヹヺ は Windows-31J にも無いため、この組では CP932 等への変換も引き続き失敗します)。逆に BMP 外の CJK 互換漢字(U+2F804 等)は BMP の統合漢字へ置換され、`type` が `nil` から `ZEN_KANJI` へ変わります (6) 不正バイト列を含む入力は入口の正規化が `ArgumentError` を投げるため、既定では変換対象が無く素通りしていた呼び出しも例外になります。結合文字ごと抽出したい場合は、UTF-8 限定で `Regexp.new("(?:#{Moji.kata})\\p{Mn}*")` のように結合マーク `\p{Mn}` を後置する正規表現を組んでください
- **文字種判定の Unicode 範囲は本家のままです**([#4](https://github.com/hazymoon/moji/issues/4))。ヷヸヹヺ・ゔ・Ё・CJK 拡張 B 以降の漢字などは判定外(`nil`)で、罫線(`ZEN_LINE`)は U+2500〜U+256F を含みません
- **`regexp` 系の `encoding` 引数には文字種依存の制限があります**([#5](https://github.com/hazymoon/moji/issues/5))。「Moji.regexp」の節を参照。また `Encoding.default_internal` を非 UTF-8 に設定すると、引数なしの `Moji.all` 等も同じ理由で例外になります
- `normalize_zen_han` は既定では全角・半角の統一のみを行い、Unicode 正規化(NFC/NFD の統一)は行いません([#1](https://github.com/hazymoon/moji/issues/1))。`nfc: true` を渡すと入出力とも NFC 正規化され、「半角カナ + 結合濁点」「NFD の全角かな」も合成済みの全角へ収束します。ただし収束先が ヷヸヹヺ になる組は Windows-31J に無いため CP932 等へは戻せません

## ロードマップ

fork の分類は「文字種」(ひらがな・カタカナ・漢字などスクリプトとしての種別)と「レパートリー」(JIS X 0208 / Windows-31J / JIS X 0213:2004 のどの文字集合に収まるか)の 2 軸で整理し、段階的に導入する計画です。

| 系列 | 方針 |
| --- | --- |
| v2.0 系 | 本家 1.6 と bug-for-bug 完全互換。挙動の変更は行わない(内部の高速化のみ) |
| v2.1 | フラグ系の既知バグ修正([#3](https://github.com/hazymoon/moji/issues/3)。既定挙動の変更はこれのみ)、NFC 正規化のオプトイン追加([#1](https://github.com/hazymoon/moji/issues/1))、レパートリー判定 API の新設([#14](https://github.com/hazymoon/moji/issues/14))、非 UTF-8 対応の deprecation warning([#5](https://github.com/hazymoon/moji/issues/5)) |
| v3.0 | 文字種判定の Unicode 準拠([#15](https://github.com/hazymoon/moji/issues/15))。かな範囲の拡張、`ZEN_GREEK` / `ZEN_CYRILLIC` / `ZEN_LINE` の文字種分類からレパートリー軸への移設、非 UTF-8 対応の削除を含む破壊的変更 |

各リリースの内容の確定状況は [milestones](https://github.com/hazymoon/moji/milestones) を参照してください。

## 開発

```console
$ bundle install
$ bundle exec rake test      # テスト実行
$ bundle exec rubocop        # スタイル検査
$ gem build moji.gemspec     # gem ビルド
```

テストスイートは現行リリースの意図した挙動を固定したゴールデンテストです(v2.0 系までは本家 1.6 の実挙動そのもの。v2.1 でフラグ系の期待値のみ [#3](https://github.com/hazymoon/moji/issues/3) の修正後の挙動に更新)。変換・判定結果の変更(Unicode 範囲の拡張など)は互換性方針の変更を伴うため、テストの期待値変更とセットで議論してください。

## 本家との差異

- 対応 Ruby を 3.3 以降に変更(Ruby 1.8/1.9 対応コードを削除)
- `eval` + ヒアドキュメントによるロード構造を通常のモジュール定義へ書き換え
- `FlagSetMaker` を `Moji::FlagSetMaker` へ移動(`Moji` の公開 API は無変更)
- v2.0 系までは公開 API・変換・判定結果とも本家 1.6 と完全互換(bug-for-bug)。v2.1 でフラグ系の既知バグ(`Moji.type?` の判定不能文字への常時 `true`・`Flags#empty?` の論理反転)を修正([#3](https://github.com/hazymoon/moji/issues/3))。それ以外の既知の制限(全角カタカナ判定が `ァ-ヶ` の範囲で `ヷヸヹヺ` を含まない、漢字判定が CJK 拡張 B 以降非対応など)はそのまま維持

詳細は [CHANGELOG.md](CHANGELOG.md) を参照。

## 作者・ライセンス

- 本家: Gimite 市川 ([gimite/moji](https://github.com/gimite/moji))
- fork: [hazymoon/moji](https://github.com/hazymoon/moji)

ライセンスは次の二層構造です。

- **本家由来の部分**: 本家は「Public Domain です。煮るなり焼くなりご自由に。」と宣言して公開されており、この fork はその宣言を法的基礎としてそのまま利用しています。本家の宣言を別のライセンスで置き換えたり、原著作者の著作権表示を fork 側が新たに主張したりすることはありません
- **fork での変更分**: [CC0-1.0](LICENSE)(Public Domain 相当の宣言 + それが法的に成立しない法域向けのフォールバック許諾)で提供します

fork 全体としても本家と同じ「ご自由に」の意図を継承しており、CC0-1.0 の採用はその意図を SPDX 識別子付きで機械可読にするためのものです。
