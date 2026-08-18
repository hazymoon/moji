# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "minitest", "~> 5.25"
  gem "rake", "~> 13.0"
  # NewCops: enable と lockfile 非コミットの構成では、rubocop のマイナー更新が
  # コード無変更の CI を赤くするため、パッチ範囲でピンする。
  gem "rubocop", "~> 1.88.0", require: false
end
