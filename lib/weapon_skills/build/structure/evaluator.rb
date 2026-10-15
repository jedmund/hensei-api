# frozen_string_literal: true

module WeaponSkills
  module Build
    module Structure
      # A small wikitext evaluator for the parts of a series template that name a skill:
      # template parameters `{{{p|default}}}`, `#vardefine` / `#vardefineecho` / `#var`,
      # `#if`, `#ifeq` and `#switch`. Any other template call is left as written, so a result
      # with `{{` in it is not fully resolved.
      #
      #   vars = Evaluator.variables(template_text, page_fields)
      #   Evaluator.evaluate("Astral {{ #switch: {{{weapon|}}} | sabre=Thrust }}", page_fields, vars)
      module Evaluator
        module_function

        # The variables the template defines at its top level, in order.
        def variables(text, args)
          vars = {}
          render(parse(text.to_s), args, vars)
          vars
        end

        def evaluate(text, args, vars)
          render(parse(text.to_s), args, vars.dup)
        end

        # → [[node, …]] (one part; parts split on "|" only inside braces)
        # node: String | [:param, parts] | [:call, parts]
        def parse(text)
          parse_seq(text, 0, nil).first.first
        end

        def parse_seq(text, pos, stop)
          i = pos
          parts = [[]]
          buf = +""
          flush = lambda do
            parts.last << buf.dup unless buf.empty?
            buf.clear
          end
          while i < text.length
            if text[i, 3] == "{{{"
              flush.call
              sub, i = parse_seq(text, i + 3, "}}}")
              parts.last << [:param, sub]
            elsif text[i, 2] == "{{"
              flush.call
              sub, i = parse_seq(text, i + 2, "}}")
              parts.last << [:call, sub]
            elsif stop && text[i, stop.length] == stop
              flush.call
              return [parts, i + stop.length]
            elsif stop && text[i] == "|"
              flush.call
              parts << []
              i += 1
            else
              buf << text[i]
              i += 1
            end
          end
          flush.call
          [parts, i]
        end

        def render(nodes, args, vars)
          nodes.map do |node|
            next node if node.is_a?(String)

            node.first == :param ? param(node.last, args, vars) : call(node.last, args, vars)
          end.join
        end

        def param(parts, args, vars)
          name = render(parts.first, args, vars).strip
          return args[name].to_s if args.key?(name)
          return render(parts[1], args, vars) if parts.size > 1

          "{{{#{name}}}}"
        end

        def call(parts, args, vars)
          head = render(parts.first, args, vars)
          fn, rest = head.strip.split(":", 2)
          rest = rest.to_s.strip
          arg = ->(n) { parts[n] ? render(parts[n], args, vars).strip : "" }
          case fn.to_s.strip.downcase
          when "#vardefine"
            vars[rest] = arg.call(1)
            ""
          when "#vardefineecho" then vars[rest] = arg.call(1)
          when "#var" then vars.fetch(rest, "")
          when "#if" then rest.empty? ? arg.call(2) : arg.call(1)
          when "#ifeq" then rest == arg.call(1) ? arg.call(2) : arg.call(3)
          when "#switch" then switch(rest, parts[1..], args, vars)
          else "{{#{parts.map { |p| render(p, args, vars) }.join('|')}}}"
          end
        end

        # MediaWiki #switch: "key=value" cases, bare keys fall through to the next value,
        # `#default=` or a final bare value is the default.
        def switch(value, cases, args, vars)
          default = nil
          matched = false
          cases.each_with_index do |c, idx|
            text = render(c, args, vars)
            key, val = text.split("=", 2)
            if val.nil?
              key = key.strip
              matched ||= key == value
              default = key if idx == cases.size - 1
              next
            end
            key = key.strip
            return val.strip if matched || key == value
            default = val.strip if key == "#default"
          end
          default.to_s
        end
      end
    end
  end
end
