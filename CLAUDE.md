# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概要

moji は日本語の文字種判定・変換（全角↔半角、ひらがな↔カタカナ、大文字↔小文字）を行う Ruby gem。[gimite/moji](https://github.com/gimite/moji) 1.6 の fork で、公開 API と変換・判定結果の互換（bug-for-bug）を保ったまま Ruby 3.3+ に現代化した v2 系。ライセンスは CC0-1.0（本家は Public Domain 宣言）。RubyGems.org には出さず、GitHub の git ソース参照で配布する。

リファレンスは README.md（日本語）とコード内の YARD コメント。API を変更したら両方を更新する。

## コマンド

- テスト: `rake test`（Minitest。`mise x ruby@3.3 -- rake test` で 3.3 でも確認する）
- スタイル検査: `mise x ruby@3.3 -- rubocop`（rubocop は Ruby 3.3 環境にインストールされている）
- gem ビルド: `gem build moji.gemspec`（バージョンは `lib/moji/version.rb`）
- CI: GitHub Actions（Ruby 3.3 / 3.4 / head で test、3.3 で rubocop）

## アーキテクチャ

- `lib/moji.rb` — 本体。`Moji` モジュールに文字種フラグ定数・`CHAR_REGEXPS`・全公開関数を定義
- `lib/moji/detail.rb` — `Moji::Detail`。変換テーブル（`ZEN_JSYMBOL_LIST` / `HAN_KATA_LIST` 等）と `Detail.convert_encoding` を持つ実装詳細（`@api private`）
- `lib/moji/flag_set_maker.rb` — `Moji::FlagSetMaker`。ビットフラグ定数を生成する汎用機構。`make_flag_set` が 18 個の基本文字種定数（各 1 ビットの `Flags` オブジェクト）を定義し、複合定数（`HAN` / `ZEN` / `KANA` / `ALL` 等）は `|` で合成する
- `CHAR_REGEXPS` は挿入順に走査され最初にマッチした文字種が勝つため、**エントリの順序に意味がある**（例: 仝 は ZEN_KANJI の範囲だが先に並ぶ ZEN_JSYMBOL に取られる）
- `han_to_zen` はカタカナ変換を JSYMBOL 変換より先に行う必要がある（濁点・半濁点記号が JSYMBOL に含まれるため。コード中にコメントあり）
- 正規表現メソッド（`Moji.kata` 等）は定数群から `define_regexp_method` で動的生成される。文字種定数を追加すれば対応メソッドも自動で生える
- 全公開関数は `Detail.convert_encoding` で入力を UTF-8 に正規化してから処理し、元エンコーディングに戻して返す

## 互換性方針（最重要）

v2 系は本家 1.6 と**変換・判定結果の完全一致（bug-for-bug）**を保証する。`test/` は本家実装の実測値を固定したゴールデンテストであり、バグに見える挙動（`type?` の nil 素通し、`ZEN_LINE` の範囲ずれ、`Flags#empty?` の論理反転、`ZEN_JSYMBOL_LIST` の ◇ 重複、Shift_JIS 入力の `han_to_zen` が例外になるケース等）も**意図的に固定している**。

- これらを「修正」してはいけない。挙動の変更（Unicode 範囲拡張を含む）は互換性方針の変更であり、テスト期待値の変更とセットでユーザーと合意してから行う
- リファクタリング時は `rake test` の GREEN に加え、必要なら新旧実装の全数突合（BMP 全コードポイントの type / 全変換のダンプ比較）で挙動同一を確認する

## 編集時の注意

- `lib/moji.rb` と `lib/moji/detail.rb` は UTF-8 のまま編集する。「〜」（U+301C）と「～」（U+FF5E）の書き分けや全角英数字等の Unicode 文字をリテラルに含むため、エンコーディング変換や Unicode 正規化を行うツールを通してはいけない
- RuboCop の恒久方針は `.rubocop.yml` に、構造由来で当面容認する違反は `.rubocop_todo.yml` に記録している。todo の解消時は該当エントリを削除して違反ゼロを確認する
