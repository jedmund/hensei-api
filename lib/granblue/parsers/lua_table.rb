# frozen_string_literal: true

require 'strscan'

module Granblue
  module Parsers
    # Reads the Lua subset gbf.wiki's data modules use (Module:StatusList): `local name = <value>`
    # statements and one `return <value>`, where a value is a table ({ [key] = v, name = v, v, … }),
    # a quoted or [[long]] string, a number, true/false/nil, or a name defined earlier.
    # Comments (`-- …`, `--[[ … ]]`) are skipped. Returns the `return` value with names resolved:
    # tables with keys become Hashes (positional values in a mixed table under 1, 2, …), tables of plain
    # values Arrays.
    class LuaTable
      class SyntaxError < StandardError; end

      ESCAPES = { 'n' => "\n", 't' => "\t", 'r' => "\r", '\\' => '\\', "'" => "'", '"' => '"' }.freeze

      def self.parse(source)
        new(source).parse
      end

      def initialize(source)
        @s = StringScanner.new(source)
        @locals = {}
      end

      def parse
        loop do
          skip_space
          if @s.scan(/local\b/)
            skip_space
            name = expect(/[A-Za-z_]\w*/, 'a name')
            skip_space
            expect(/=/, '=')
            @locals[name] = value
          elsif @s.scan(/return\b/)
            return value
          else
            error('local or return')
          end
        end
      end

      private

      def value
        skip_space
        if @s.scan('{') then table
        elsif (quote = @s.scan(/['"]/)) then string(quote)
        elsif @s.scan(/\[(=*)\[/) then long_string("]#{@s[1]}]")
        elsif (number = @s.scan(/-?\d+(?:\.\d+)?/)) then number.include?('.') ? number.to_f : number.to_i
        elsif @s.scan(/true\b/) then true
        elsif @s.scan(/false\b/) then false
        elsif @s.scan(/nil\b/) then nil
        elsif (name = @s.scan(/[A-Za-z_]\w*/)) then @locals.fetch(name) { error("a defined name (got #{name})") }
        else error('a value')
        end
      end

      def table
        hash = {}
        array = []
        loop do
          skip_space
          break if @s.scan('}')

          if @s.check(/\[(?!=*\[)/)
            @s.scan('[')
            key = value
            skip_space
            expect(/\]/, ']')
            skip_space
            expect(/=/, '=')
            hash[key] = value
          elsif @s.check(/[A-Za-z_]\w*\s*=(?!=)/)
            key = @s.scan(/[A-Za-z_]\w*/)
            skip_space
            @s.scan('=')
            hash[key] = value
          else
            array << value
          end
          skip_space
          @s.scan(/[,;]/)
        end
        return array if hash.empty? && array.any?

        # A mixed table keeps its positional values under 1, 2, … as Lua does.
        array.each_with_index { |value, i| hash[i + 1] = value }
        hash
      end

      def string(quote)
        out = +''
        loop do
          chunk = @s.scan(quote == "'" ? /[^'\\\n]+/ : /[^"\\\n]+/)
          out << chunk if chunk
          if @s.scan("\\")
            char = @s.getch or error('an escape')
            out << ESCAPES.fetch(char, char)
          elsif @s.scan(quote == "'" ? /'/ : /"/)
            return out
          else
            error('the end of a string')
          end
        end
      end

      # [[ … ]] / [==[ … ]==]: taken verbatim (a leading newline dropped, as Lua does).
      def long_string(close)
        start = @s.pos
        @s.skip_until(Regexp.new(Regexp.escape(close))) or error(close)
        @s.string[start...(@s.pos - close.size)].sub(/\A\r?\n/, '')
      end

      def skip_space
        loop do
          @s.skip(/\s+/)
          if @s.scan(/--\[(=*)\[/)
            close = "]#{@s[1]}]"
            @s.skip_until(Regexp.new(Regexp.escape(close))) or error(close)
          elsif @s.scan('--')
            @s.skip_until(/\n|\z/)
          else
            break
          end
        end
      end

      def expect(pattern, what)
        @s.scan(pattern) || error(what)
      end

      def error(what)
        line = @s.string[0...@s.pos].count("\n") + 1
        raise SyntaxError, "expected #{what} at line #{line}: #{@s.peek(30).inspect}"
      end
    end
  end
end
