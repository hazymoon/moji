# Changelog

このファイルの形式は [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に、
バージョニングは [Semantic Versioning](https://semver.org/lang/ja/) に従う。

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
