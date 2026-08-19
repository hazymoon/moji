# frozen_string_literal: true

require "test_helper"

# 非 UTF-8 対応の deprecation warning(v2.1 で追加。#5)のテスト。
# warn(category: :deprecated) は Warning[:deprecated] が false(既定)だと
# Warning.warn まで届かないため、テスト内で明示的に true へ設定して捕捉する
# (Rake::TestTask の warning オプションに暗黙依存しない)。
class TestDeprecation < Minitest::Test
  include MojiTestHelpers

  # Warning[:deprecated] を有効化し Warning.warn を差し替えて、ブロック中に
  # 発生した deprecation warning のメッセージ配列を返す。終了時に必ず復元する。
  # Warning.warn の実体は extend されたモジュールのインスタンスメソッドなので、
  # define_singleton_method で shadow し、復元は shadow の除去で行う。
  def capture_deprecation_warnings
    original_flag = Warning[:deprecated]
    Warning[:deprecated] = true
    captured = []
    Warning.define_singleton_method(:warn) do |message, **kwargs|
      # :deprecated だけを拾う: 差し替えは全カテゴリの警告を受けるため、無関係な
      # 実行時警告(正規表現合成の duplicated range 等)が混ざると件数の assert が
      # 誤検知で壊れる。deprecation warning は必ず category: :deprecated を伴う。
      captured << message if kwargs[:category] == :deprecated
    end
    yield
    captured
  ensure
    # フラグ復元を先に置く: remove_method が NameError になっても
    # Warning[:deprecated] = true をプロセスへ漏らさない。
    Warning[:deprecated] = original_flag
    Warning.singleton_class.send(:remove_method, :warn)
  end

  def assert_single_deprecation(messages, pattern)
    assert_equal(1, messages.size, messages.inspect)
    assert_match(pattern, messages.first)
  end

  # ---- 経路 1: 非 UTF-8 の文字列入力 ----

  def test_non_utf8_string_input_warns
    messages = capture_deprecation_warnings do
      Moji.type("Ａ".encode(Encoding::Windows_31J))
    end
    assert_single_deprecation(messages, /non-UTF-8 string input is deprecated.*Windows-31J/)
  end

  def test_internal_delegation_warns_only_once
    # type? → type、normalize_zen_han → han_to_zen / zen_to_han の内部委譲は
    # UTF-8 化済み文字列を受けるため、警告は公開入口の 1 回だけ出る。
    messages = capture_deprecation_warnings do
      Moji.type?("Ａ".encode(Encoding::Windows_31J), Moji::ZEN)
    end
    assert_equal(1, messages.size, messages.inspect)

    messages = capture_deprecation_warnings do
      Moji.normalize_zen_han("ｶﾞ".encode(Encoding::Windows_31J))
    end
    assert_equal(1, messages.size, messages.inspect)
  end

  # ---- 経路 2: 正規表現系の非 UTF-8 エンコーディング(明示・default_internal とも) ----

  def test_regexp_with_non_utf8_encoding_warns_even_on_cache_hit
    # 警告はメモ化より前にあるため、キャッシュヒットする 2 回目も警告される
    # (警告の有無がテスト実行順序・キャッシュ状態に依存しない)。
    messages = capture_deprecation_warnings do
      Moji.regexp(Moji::KATA, Encoding::Windows_31J)
      Moji.regexp(Moji::KATA, Encoding::Windows_31J)
    end
    assert_equal(2, messages.size, messages.inspect)
    assert_match(/non-UTF-8 regexp support is deprecated.*Windows-31J/, messages.first)
  end

  def test_regexp_accessor_with_non_utf8_encoding_warns
    messages = capture_deprecation_warnings { Moji.kata(Encoding::Windows_31J) }
    assert_single_deprecation(messages, /non-UTF-8 regexp support is deprecated/)
  end

  def test_regexp_with_encoding_name_string_warns_and_returns_regexp
    # encoding 引数は名前文字列でも動いていた(String#encode が名前を受けるため。
    # v2.0.2 の実測挙動)。警告の追加でこの経路を壊さない。
    reg = nil
    messages = capture_deprecation_warnings do
      reg = Moji.regexp(Moji::KATA, "Windows-31J")
    end
    assert_equal(Encoding::Windows_31J, reg.encoding)
    assert_single_deprecation(messages, /non-UTF-8 regexp support is deprecated.*Windows-31J/)
  end

  def test_regexp_warning_is_not_dispatched_to_includer_warn
    # regexp は module_function であり include Moji したクラスの private メソッド
    # としても呼ばれる。レシーバなしの warn は includer 自身の warn(Logger#warn の
    # ような arity 違いのメソッド)に解決されて例外になるため、Kernel.warn を明示する。
    includer = Class.new do
      include Moji

      def warn(_message)
        raise "includer の warn が呼ばれた"
      end

      def kata_windows31j
        kata(Encoding::Windows_31J)
      end
    end
    messages = capture_deprecation_warnings { includer.new.kata_windows31j }
    assert_single_deprecation(messages, /non-UTF-8 regexp support is deprecated/)
  end

  def test_default_internal_non_utf8_warns
    messages = capture_deprecation_warnings do
      with_default_internal(Encoding::Windows_31J) do
        # with_default_internal は設定時警告の抑止に $VERBOSE = nil(-W0 相当)を
        # 使うが、それでは Kernel#warn 自体が無効になるため、計測区間だけ戻す。
        $VERBOSE = false
        Moji.regexp(Moji::KATA)
      end
    end
    # 引数明示と default_internal 由来は区別せず同じ警告を出す。
    assert_single_deprecation(messages, /non-UTF-8 regexp support is deprecated.*Windows-31J/)
  end

  # ---- 非発火: UTF-8 経路と判定系 API ----

  def test_utf8_paths_do_not_warn
    messages = capture_deprecation_warnings do
      Moji.type("Ａ")
      Moji.zen_to_han("Ｒｕｂｙ")
      Moji.zen_to_han("ガ", nfc: true)
      Moji.regexp(Moji::KATA)
      Moji.kata
    end
    assert_empty(messages)
  end

  def test_us_ascii_is_not_deprecated
    # US-ASCII は UTF-8 の部分集合で v3.0 でも受け付けるため警告しない。
    # 一方 ASCII-8BIT(バイナリ)は内容依存の変換になるため対象のまま。
    messages = capture_deprecation_warnings do
      Moji.type("A".encode(Encoding::US_ASCII))
      Moji.regexp(Moji::HAN_UPPER, Encoding::US_ASCII)
    end
    assert_empty(messages)

    messages = capture_deprecation_warnings { Moji.type("A".b) }
    assert_single_deprecation(messages, /non-UTF-8 string input is deprecated.*ASCII-8BIT/)
  end

  def test_encodable_and_unencodable_do_not_warn
    # encodable? / unencodable の encoding 引数と非 UTF-8 入力は「判定対象の指定」
    # であり deprecation の対象外(v3.0 でも受け付ける)。
    messages = capture_deprecation_warnings do
      Moji.encodable?("ガ".encode(Encoding::Windows_31J), Encoding::Windows_31J)
      Moji.encodable?("髙", Encoding::Shift_JIS)
      Moji.unencodable(Encoding::Windows_31J)
    end
    assert_empty(messages)
  end

  # ---- 既定では警告が抑止される(category: :deprecated の性質) ----

  def test_warning_is_suppressed_when_deprecated_category_is_disabled
    # Warning.warn の差し替えでは検証しない: カテゴリのフィルタ位置が Ruby の
    # バージョンで異なる(3.3 は Warning.warn の既定実装側、4.0 は Kernel#warn 側)
    # ため、観測可能な stderr 出力で確認する。
    original_flag = Warning[:deprecated]
    Warning[:deprecated] = false
    _out, err = capture_io do
      Moji.type("Ａ".encode(Encoding::Windows_31J))
    end
    assert_empty(err)
  ensure
    Warning[:deprecated] = original_flag
  end
end
