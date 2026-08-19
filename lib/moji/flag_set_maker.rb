# frozen_string_literal: true

module Moji
  # ビットフラグ定数群を生成する汎用モジュール。
  # extend したモジュールで make_flag_set を呼ぶと、各 1 ビットの Flags オブジェクトが
  # 定数として定義される。複合フラグは | で合成する。
  module FlagSetMaker
    # フラグ名の集合を管理し、フラグ値の文字列化・検証を行う。
    class FlagSet
      def initialize(mod, names)
        @module = mod
        @flag_names = names.to_a
        @flag_names.each_with_index do |name, i|
          mod.const_set(name, Flags.new(1 << i, self))
        end
      end

      def to_s(value)
        names = []
        @flag_names.each_with_index { |name, i| names.push(name) if value[i] == 1 }
        if names.empty?
          ""
        elsif names.size == 1
          names[0].to_s
        else
          "(#{names.join('|')})"
        end
      end

      def inspect(value = nil)
        value ? format("%p::%s", @module, to_s(value)) : super()
      end

      def validate(value)
        value & ((1 << @flag_names.size) - 1)
      end
    end

    # 単一または合成のビットフラグ値。| & ~ で合成し、include? でビット包含を判定する。
    class Flags
      def initialize(value, flag_set)
        @value = flag_set.validate(value)
        @flag_set = flag_set
      end

      def to_i
        @value
      end

      def to_s
        @flag_set.to_s(@value)
      end

      def inspect
        @flag_set.inspect(@value)
      end

      def ==(other)
        other.is_a?(Flags) && @flag_set == other.flag_set && @value == other.to_i
      end

      alias eql? ==

      def hash
        to_i.hash
      end

      def &(other)
        new_flag(@value & other.to_i)
      end

      def |(other)
        new_flag(@value | other.to_i)
      end

      def ~
        new_flag(~@value)
      end

      def include?(flags)
        # 本家 1.6 では nil.to_i == 0 により include?(nil) が常に true になり、
        # Moji.type? が判定不能な文字へ true を返す原因だった。v2.1 で明示拒否に
        # 修正した（#3）。& / | の nil 受理（同根の to_i 暗黙変換）は #17 で追跡。
        return false if flags.nil?

        @value.allbits?(flags.to_i)
      end

      # 歴史的経緯: 本家 1.6 では論理が反転しており（実装が @value != 0）、
      # 値が非ゼロのとき true を返していた。v2.0 系までは bug-for-bug 互換のため
      # 維持していたが、v2.1 で名前どおりの意味（値 0 のとき true）へ修正した（#3）。
      def empty?
        @value.zero?
      end

      protected

      attr_reader(:flag_set)

      private

      def new_flag(value)
        Flags.new(value, @flag_set)
      end
    end

    def make_flag_set(names)
      FlagSet.new(self, names)
    end
  end
end
