# Changelog

このファイルの形式は [Keep a Changelog](https://keepachangelog.com/ja/1.0.0/) に、
バージョニングは [Semantic Versioning](https://semver.org/lang/ja/) に従う。

## [2.0.0] - 未リリース

[gimite/moji](https://github.com/gimite/moji) 1.6 からの fork。
公開 API と変換・判定結果は本家 1.6 と完全互換（bug-for-bug）。挙動の改善は行っていない。

### 破壊的変更

- 対応 Ruby を 3.3 以降に変更（`required_ruby_version >= 3.3.0`）
- Ruby 1.8/1.9 互換コードを削除（`$KCODE` / NKF / jcode / `RUBY_VERSION` 分岐）
- `FlagSetMaker` をトップレベルから `Moji::FlagSetMaker` へ移動
  （`require "flag_set_maker"` の直接利用のみ非互換。`Moji` の公開 API は無変更）
- 開発用メソッド `Moji.test` を削除（Minitest によるテストスイートへ置き換え）
- `setup.rb` によるレガシーインストール方式を廃止

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
