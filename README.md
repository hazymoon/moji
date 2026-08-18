# moji

日本語の文字種判定、文字種変換(半角→全角、ひらがな→カタカナなど)を行う Ruby ライブラリです。

[gimite/moji](https://github.com/gimite/moji) 1.6 の fork で、公開 API と変換・判定結果の互換性を保ったまま Ruby 3.3 以降に対応しています。

> **English**: moji is a Ruby library for Japanese character type classification and conversion (half-width ↔ full-width, hiragana ↔ katakana, upper ↔ lower case). This is a fork of [gimite/moji](https://github.com/gimite/moji) 1.6, modernized for Ruby 3.3+ while keeping full API and behavioral compatibility.

## 対応環境

Ruby 3.3 以降。

## インストール

RubyGems.org では配布していません。Gemfile に git ソースで指定してください。

```ruby
gem "moji", github: "hazymoon/moji"
```

## 使い方

どのエンコーディングの文字列を渡しても動作しますが、`String#encoding` が正しく設定されている必要があります。正規表現を返す関数(`Moji.kata` など)は `Encoding.default_internal`(未設定の場合は UTF-8)用の正規表現を返します。その他のエンコーディング用の正規表現は `Moji.kata(Encoding::SJIS)` などで取得できます(文字種依存の制限あり。「[既知の制限](#既知の制限)」参照)。

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

### `Moji.type(ch)`

文字 `ch` の文字種を返します。「一番細かい分類」の定数のうち 1 つを返します。

上の分類に当てはまらない文字(Unicode のハングルなど)に対しては `nil` を返します。また、Unicode の BMP 外の文字に対しても `nil` を返します。文字が割り当てられていない文字コードに対する結果は不定です(`nil` を返す事もあります)。

```ruby
Moji.type("漢")   # => Moji::ZEN_KANJI
```

### `Moji.type?(ch, type)`

文字 `ch` が文字種 `type` に含まれれば `true` を返します。`type` には全ての定数と、それらを `|` で結んだものを使えます。

```ruby
Moji.type?("Ａ", Moji::ZEN)   # => true
```

### `Moji.regexp(type[, encoding])`

文字種 `type` の 1 文字を表す正規表現を返します。`type` には全ての定数と、それらを `|` で結んだものを使えます。

`encoding` に `Encoding` オブジェクトを渡すと、その文字種の正規表現を指定のエンコーディングへ変換して返します。省略すると `Encoding.default_internal`(未設定の場合は `Encoding::UTF_8`)とみなします。

ただし変換できるのは文字種の全文字が対象エンコーディングに存在する場合だけで、以下の制限があります([#5](https://github.com/hazymoon/moji/issues/5))。

- `ALL` / `ZEN` / `ZEN_JSYMBOL` など「〜」(U+301C)と「～」(U+FF5E)の両方を含む文字種は、Shift_JIS / Windows-31J / EUC-JP のいずれを渡しても `Encoding::UndefinedConversionError` になります
- ASCII のみで定義された文字種(`HAN_NUMBER` / `HAN_UPPER` など)は `encoding` 引数が無視され US-ASCII の正規表現が返ります
- `ZEN_KANJI` / `ZEN_LINE` は内部が `\uXXXX` エスケープのため `encoding` 引数が無視され、常に UTF-8 の正規表現が返ります

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

## 既知の制限

本家 1.6 との完全互換(bug-for-bug)方針により、以下の挙動を意図的に維持しています。改善候補は [Issues](https://github.com/hazymoon/moji/issues)(`v2.1-candidate` ラベル)で追跡しています。

- **`Moji.type?` は判定不能な文字に対して常に `true` を返します**([#3](https://github.com/hazymoon/moji/issues/3))。`Moji.type` が `nil` を返す文字(ハングル・絵文字・BMP 外など)では、どの文字種を渡しても `true` になります。「日本語の文字種に含まれるか」のバリデーションには `Moji.type` の `nil` 判定か正規表現を使ってください
- **文字列はコードポイント単位で処理されます**([#1](https://github.com/hazymoon/moji/issues/1))。結合文字列(NFD 形式のかな・結合アクセント・異体字セレクタ)は基底文字だけが変換・マッチの対象になります。特に NFD の全角カナを `zen_to_han` すると「半角カナ + 結合濁点」という CP932 等へ変換できない列が生じ、後段の `encode` で初めて失敗します。NFD が混入しうる入力(HFS+ 由来のファイル名・ZIP・macOS からのアップロード等)は、呼び出し前に `unicode_normalize(:nfc)` してください(NFKC は全角・半角の区別ごと潰すため使わないでください)
- **文字種判定の Unicode 範囲は本家のままです**([#4](https://github.com/hazymoon/moji/issues/4))。ヷヸヹヺ・ゔ・Ё・CJK 拡張 B 以降の漢字などは判定外(`nil`)で、罫線(`ZEN_LINE`)は U+2500〜U+256F を含みません
- **`regexp` 系の `encoding` 引数には文字種依存の制限があります**([#5](https://github.com/hazymoon/moji/issues/5))。「Moji.regexp」の節を参照。また `Encoding.default_internal` を非 UTF-8 に設定すると、引数なしの `Moji.all` 等も同じ理由で例外になります
- `normalize_zen_han` は全角・半角の統一のみを行い、Unicode 正規化(NFC/NFD の統一)は行いません([#1](https://github.com/hazymoon/moji/issues/1))

## 開発

```console
$ bundle install
$ bundle exec rake test      # テスト実行
$ bundle exec rubocop        # スタイル検査
$ gem build moji.gemspec     # gem ビルド
```

テストスイートは本家 1.6 の実挙動を固定したゴールデンテストです。変換・判定結果の変更(Unicode 範囲の拡張など)は互換性方針の変更を伴うため、テストの期待値変更とセットで議論してください。

## 本家との差異

- 対応 Ruby を 3.3 以降に変更(Ruby 1.8/1.9 対応コードを削除)
- `eval` + ヒアドキュメントによるロード構造を通常のモジュール定義へ書き換え
- `FlagSetMaker` を `Moji::FlagSetMaker` へ移動(`Moji` の公開 API は無変更)
- 公開 API・変換・判定結果は本家 1.6 と完全互換(bug-for-bug)。既知の制限(全角カタカナ判定が `ァ-ヶ` の範囲で `ヷヸヹヺ` を含まない、漢字判定が CJK 拡張 B 以降非対応など)もそのまま維持

詳細は [CHANGELOG.md](CHANGELOG.md) を参照。

## 作者・ライセンス

- 本家: Gimite 市川 ([gimite/moji](https://github.com/gimite/moji))
- fork: [hazymoon/moji](https://github.com/hazymoon/moji)

ライセンスは次の二層構造です。

- **本家由来の部分**: 本家は「Public Domain です。煮るなり焼くなりご自由に。」と宣言して公開されており、この fork はその宣言を法的基礎としてそのまま利用しています。本家の宣言を別のライセンスで置き換えたり、原著作者の著作権表示を fork 側が新たに主張したりすることはありません
- **fork での変更分**: [CC0-1.0](LICENSE)(Public Domain 相当の宣言 + それが法的に成立しない法域向けのフォールバック許諾)で提供します

fork 全体としても本家と同じ「ご自由に」の意図を継承しており、CC0-1.0 の採用はその意図を SPDX 識別子付きで機械可読にするためのものです。
