# frozen_string_literal: true

require_relative "lib/moji/version"

Gem::Specification.new do |s|
  s.name = "moji"
  s.version = Moji::VERSION
  s.authors = ["Hiroshi Ichikawa", "Kakeru Sugibuchi"]
  s.email = ["fine.despair@gmail.com"]
  s.summary = "Character type classification/conversion for Japanese"
  s.description =
    "日本語の文字種判定・変換(全角↔半角、ひらがな↔カタカナ、大文字↔小文字)を行うライブラリ。" \
    "gimite/moji の Ruby 3.3+ 対応 fork。"
  s.homepage = "https://github.com/hazymoon/moji"
  s.license = "CC0-1.0"
  s.required_ruby_version = ">= 3.3.0"

  s.files = [
    "CHANGELOG.md",
    "LICENSE",
    "README.md",
    "lib/moji.rb",
    "lib/moji/flag_set_maker.rb",
    "lib/moji/version.rb",
  ]
  s.require_paths = ["lib"]

  s.metadata = {
    "source_code_uri" => s.homepage,
    "changelog_uri" => "#{s.homepage}/blob/master/CHANGELOG.md",
    "rubygems_mfa_required" => "true",
  }
end
