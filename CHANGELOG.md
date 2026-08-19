# Changelog

このファイルの形式は [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に、
バージョニングは [Semantic Versioning](https://semver.org/lang/ja/) に従う。

## [2.1.0] - 未リリース

### 追加

- 符号化可否判定 API `Moji.encodable?` / `Moji.unencodable` を追加
  （[#14](https://github.com/hazymoon/moji/issues/14)）。文字列が
  Shift_JIS / Windows-31J / EUC-JIS-2004 へ無損失に符号化できるかの判定と、
  符号化できない文字にマッチする正規表現を提供する。判定の定義は
  「Ruby の当該エンコーディングへ `String#encode` で変換できるか」で、
  範囲表は Ruby 3.3 の変換表から生成した（`tools/gen_encodable_tables.rb`。
  生成表と実行環境の変換表の一致は全コードポイントの replay テストが
  CI の全 Ruby バージョンで機械検証する）
- 文字列を受ける全関数（`type` / `type?` / 変換系 7 関数）に `nfc:`
  キーワード引数を追加（[#1](https://github.com/hazymoon/moji/issues/1)、
  既定 false）。有効にすると、文字列を返す関数は入力と結果の両方を、
  `type` / `type?` は入力のみを NFC 正規化する。NFD の全角カナを
  `zen_to_han` したときに生じる「半角カナ + 結合濁点」という CP932 等へ
  変換できない列を防げる（う・ワ行 + 結合濁点など、合成先が本家の
  判定・変換範囲の外に出る組を除く）。NFC の singleton 分解により
  CJK 互換漢字が標準字体へ置換される、不正バイト列が入口の正規化で
  `ArgumentError` になる等の副作用がある（README の既知の制限を参照）。
  既定では従来と完全に同じ挙動（オブジェクト同一性を含む）を保つ

### 修正（破壊的変更）

- `Moji.type?` が判定不能な文字（`Moji.type` が `nil` を返す文字）に対して
  常に `true` を返すバグを修正し、`false` を返すようにした
  （[#3](https://github.com/hazymoon/moji/issues/3)）。本家 1.6 では
  `Flags#include?(nil)` が `nil.to_i == 0` により常に true だった。
  空文字列に対する `Moji.type?` も同様に true から false に変わる。
  「含まれれば通す」判定では受理範囲が狭まる方向の変化だが、文字種判定の
  Unicode 範囲は本家のまま（[#4](https://github.com/hazymoon/moji/issues/4)）
  のため、ゔ・ヷ など分類外扱いの正当な日本語文字も弾かれるようになる。
  逆に「true なら弾く」判定では判定不能な文字がフィルタを通過するようになり、
  受理範囲は広がる。v2.0 系で回避策としていた `Moji.type` の `nil` 判定は
  v2.1 でも同じ結果を返すため、移行時にそのまま残してよい
- `Moji::FlagSetMaker::Flags#empty?` の論理反転（値が非ゼロのとき true）を
  修正し、名前どおり「値 0 のとき true」を返すようにした
  （[#3](https://github.com/hazymoon/moji/issues/3)）
- 値 0 のフラグの `Flags#to_s` が `""` を返す挙動は仕様として維持。
  `Flags#&` / `#|` の nil 受理（同根の `to_i` 暗黙変換）は
  [#17](https://github.com/hazymoon/moji/issues/17) で別途追跡（本版では変更なし）

## [2.0.2] - 2026-08-19

変換・判定結果と公開 API は 2.0.1 と完全一致（v2.0.1 との全出力突合
2,955,158 件で diff ゼロを実測）。

### 変更

- 内部高速化（[#2](https://github.com/hazymoon/moji/issues/2)）:
  `Moji.regexp` と定数対応メソッド（`Moji.kata` 等）の合成結果をメモ化
  （`regexp(ALL)` で約 72 倍）、変換系の対応表を事前計算（`zen_to_han`
  約 2.3 倍・`han_to_zen` 約 1.7 倍）、`Moji.type` を範囲表の二分探索に
  置き換え（約 4〜7 倍）
- `Moji::Detail` を `lib/moji/detail.rb` へ分離
  （[#8](https://github.com/hazymoon/moji/issues/8)）
- README の既知の制限に `han_to_zen` の非 UTF-8 入力例外・`Encoding::SJIS`
  別名の注意・結合文字込み抽出のレシピを追記
  （[#1](https://github.com/hazymoon/moji/issues/1) /
  [#5](https://github.com/hazymoon/moji/issues/5)）
- ゴールデンテストの互換データ表とヘルパーを test_helper へ集約
  （[#6](https://github.com/hazymoon/moji/issues/6)）

### 高速化に伴い許容した観測可能な変化（値の挙動は完全同一）

- 同一の文字種・エンコーディングに対する `Moji.regexp` が同一の Regexp
  オブジェクトを返す（`equal?` で区別している場合のみ影響）
- `Moji::CHAR_REGEXPS` を実行時に差し替えても `type` / `regexp` / 変換系の
  結果に反映されない（各キーの初回呼び出し時点の内容で固定される。
  差し替えの反映は従来も文書化されていない内部挙動）

## [2.0.1] - 2026-08-18

### 変更

- README のライセンス節を二層構造（本家由来部分は本家の Public Domain 宣言を
  そのまま法的基礎とし、fork の変更分のみ CC0-1.0）で明文化。コード・挙動の
  変更はなし

## [2.0.0] - 2026-08-18

[gimite/moji](https://github.com/gimite/moji) 1.6 からの fork。
公開 API と変換・判定結果は本家 1.6 と完全互換（bug-for-bug）。挙動の改善は行っていない。

### 破壊的変更

- 対応 Ruby を 3.3 以降に変更（`required_ruby_version >= 3.3.0`）
- Ruby 1.8/1.9 互換コードを削除（`$KCODE` / NKF / jcode / `RUBY_VERSION` 分岐）
- `FlagSetMaker` をトップレベルから `Moji::FlagSetMaker` へ移動
  （`require "flag_set_maker"` の直接利用のみ非互換。`Moji` の公開 API は無変更）
- 開発用メソッド `Moji.test` を削除（Minitest によるテストスイートへ置き換え）
- `setup.rb` によるレガシーインストール方式を廃止
- `frozen_string_literal` の導入により、変換テーブルの文字列定数（`Moji::Detail` 配下）が
  凍結される（本家では可変だった）。`Moji::CHAR_REGEXPS` は本家同様に可変のまま

### 変更

- `eval` + ヒアドキュメントによるロード構造を通常のモジュール定義へ書き換え
  （Ruby 1.8 の `$KCODE` 対応のための構造だったため）
- リファレンスドキュメントを RD 形式ブロックから README.md + YARD コメントへ移行
- ライセンス表記を CC0-1.0（SPDX 識別子付き Public Domain 相当）として明文化

### 追加

- Minitest による互換テストスイート（本家 1.6 の実挙動を固定）
- GitHub Actions CI（Ruby 3.3 / 3.4 / head）
- RuboCop によるスタイル検査
- Rakefile / Gemfile / CHANGELOG.md / LICENSE

## 1.6 以前

本家の更新履歴は [gimite/moji](https://github.com/gimite/moji) を参照。
