# frozen_string_literal: true

require "cgi"

module WeaponSkills
  # Turns the gbf.wiki markup in a skill description into display segments, so clients
  # never parse wikitext:
  #
  #   "Take {{tt|5% damage|Based on max HP.}} every turn"
  #   → [{ text: "Take " }, { text: "5% damage", tooltip: "Based on max HP." }, { text: " every turn" }]
  #
  # Segments carry `strong: true` for '''bold''' and `tooltip:` for hover text ({{tt}},
  # {{status}} amounts and durations, {{atkmod}} modifiers). Line breaks are "\n" in text.
  # Pure: no database, no network. The stored description stays raw wikitext.
  module WikiMarkup
    ELEMENT_NAMES = {
      "wind" => { en: "Wind", ja: "風" }, "fire" => { en: "Fire", ja: "火" },
      "water" => { en: "Water", ja: "水" }, "earth" => { en: "Earth", ja: "土" },
      "dark" => { en: "Dark", ja: "闇" }, "light" => { en: "Light", ja: "光" }
    }.freeze

    # The element each element is strong against ({{WeaponWeakElement}}).
    ADVANTAGE = { "fire" => "wind", "wind" => "earth", "earth" => "water", "water" => "fire",
                  "light" => "dark", "dark" => "light" }.freeze

    LABELS = {
      en: { max: "Max %s", indefinite: "Indefinite", modifier: "Modifier: %s", element: "same-element" },
      ja: { max: "最大%s", indefinite: "永続", modifier: "枠: %s", element: "同属性" }
    }.freeze

    MODIFIERS = { "ex" => "EX", "normal" => "Normal", "omega" => "Omega", "magna" => "Omega" }.freeze

    module_function

    # element: the weapon's element as GranblueEnums::ELEMENTS id (1-6) or name; it fills
    # {{WeaponElement}} and friends. locale: :en, or :ja / :jp.
    def segments(text, element: nil, locale: :en)
      return [] if text.blank?

      Renderer.new(element: element_key(element), locale: locale.to_sym == :en ? :en : :ja)
              .render_all(Parser.new(text).parse)
    end

    def plain(text, **)
      segments(text, **).sum("") { |segment| segment[:text] }
    end

    def element_key(element)
      key = element.is_a?(Integer) ? GranblueEnums::ELEMENTS.key(element)&.to_s : element.to_s
      key = key.to_s.downcase
      ELEMENT_NAMES.key?(key) ? key : nil
    end

    # Wikitext → nodes. A node is a String, or an Array:
    #   [:template, parts], [:param, parts], [:link, parts]  (parts split on top-level "|")
    #   [:bold], [:italic], [:br]
    # Nesting is tracked by recursion, so {{WeaponElement|{{{element|}}}}} and templates
    # inside {{tt}} arguments parse correctly. Unclosed constructs end at the end of text.
    class Parser
      OPENERS = { "{{{" => [:param, "}}}"], "{{" => [:template, "}}"], "[[" => [:link, "]]"] }.freeze

      def initialize(text)
        @text = text
        @pos = 0
      end

      def parse
        parse_until([]).first
      end

      private

      def parse_until(terminators)
        nodes = []
        buffer = +""
        flush = lambda do
          nodes << decode(buffer.dup) unless buffer.empty?
          buffer.clear
        end
        while @pos < @text.length
          if (hit = terminators.find { |t| at?(t) })
            flush.call
            return [nodes, hit]
          end
          if (opener = OPENERS.keys.find { |o| at?(o) })
            flush.call
            kind, close = OPENERS[opener]
            @pos += opener.length
            nodes << [kind, parse_parts(close)]
          elsif at?("'''")
            flush.call
            nodes << [:bold]
            @pos += 3
          elsif at?("''")
            flush.call
            nodes << [:italic]
            @pos += 2
          elsif @text[@pos] == "<" && (tag = tag_node)
            flush.call
            nodes << tag unless tag == :skip
          else
            buffer << @text[@pos]
            @pos += 1
          end
        end
        flush.call
        [nodes, nil]
      end

      def parse_parts(close)
        parts = [[]]
        loop do
          nodes, hit = parse_until(["|", close])
          parts.last.concat(nodes)
          return parts if hit.nil?

          @pos += hit.length
          return parts if hit == close

          parts << []
        end
      end

      # <br>/<hr> → line break; <ref>…</ref> dropped; any other tag stripped (content kept).
      def tag_node
        rest = @text[@pos..]
        m = rest.match(%r{\A<ref\b[^>]*/>}i) || rest.match(%r{\A<ref\b[^>]*>.*?</ref\s*>}im) ||
            rest.match(/\A<(?:br|hr)\b[^>]*>/i) || rest.match(%r{\A</?[a-z][^>]*>}i)
        return nil unless m

        @pos += m[0].length
        m[0].match?(/\A<(?:br|hr)\b/i) ? [:br] : :skip
      end

      def at?(token) = @text[@pos, token.length] == token

      def decode(text)
        CGI.unescapeHTML(text.gsub("&nbsp;", " "))
      end
    end

    class Renderer
      def initialize(element:, locale:)
        @element = element
        @locale = locale
        @strong = false
      end

      def render_all(nodes)
        tidy(render(nodes))
      end

      private

      def labels = LABELS.fetch(@locale)

      def render(nodes)
        Array(nodes).flat_map { |node| render_node(node) }
      end

      def render_node(node)
        return [segment(node)] if node.is_a?(String)

        case node.first
        when :bold then @strong = !@strong
                        []
        when :br then [segment("\n")]
        when :link then render_link(node.last)
        when :param then node.last.size > 1 ? render(node.last[1]) : []
        when :template then render_template(node.last)
        else [] # :italic is dropped
        end
      end

      def segment(text, tooltip: nil)
        { text: text, strong: @strong || nil, tooltip: tooltip }.compact
      end

      def render_link(parts)
        return [] if text_of(parts.first).strip.match?(/\A(?:File|Image|Category|Media):/i)

        render(parts.size > 1 ? parts.last : parts.first)
      end

      def render_template(parts)
        name = text_of(parts.first).strip
        positional, named = split_args(parts.drop(1))
        case name.downcase
        when "tt" then with_tooltip(render(positional[0]), tooltip_text(positional[1]))
        when "status" then with_tooltip(render(positional[0]), status_tooltip(named))
        when "atkmod" then atkmod(positional[0], named["m"])
        when "weaponelement", "element" then [segment(element_name(text_of(positional[0]).strip.downcase))]
        when "weaponweakelement" then [segment(element_name(nil, weak: true))]
        else render(positional[0] || named.values.first)
        end
      end

      # A part whose text starts "key=" is a named argument; the rest are positional.
      def split_args(args)
        positional = []
        named = {}
        args.each do |nodes|
          first = nodes.first
          if first.is_a?(String) && (m = first.match(/\A\s*([A-Za-z_][\w-]*)\s*=/))
            named[m[1]] = [first[m[0].length..], *nodes.drop(1)].reject { |n| n == "" }
          else
            positional << nodes
          end
        end
        [positional, named]
      end

      def with_tooltip(segments, tooltip)
        return segments if tooltip.blank?

        segments.map { |s| s.merge(tooltip: tooltip) }
      end

      # Hover text is plain: bold dropped, line breaks kept.
      def tooltip_text(nodes)
        return nil if nodes.nil?

        saved = @strong
        @strong = false
        text = render(nodes).sum("") { |s| s[:text] }
        @strong = saved
        tidy_text(text).strip.presence
      end

      def status_tooltip(named)
        amount = tooltip_text(named["a"])
        max = tooltip_text(named["am"])
        duration = tooltip_text(named["t"])
        duration = labels[:indefinite] if duration == "i"
        first = [amount, max && format(labels[:max], max), duration].compact.join(" · ").presence
        [first, tooltip_text(named["c"])].compact.join("\n").presence
      end

      def atkmod(label, modifier)
        text = label ? render(label) : [segment("ATK")]
        key = tooltip_text(modifier).to_s.downcase
        name = MODIFIERS[key] || key.capitalize.presence
        with_tooltip(text, name && format(labels[:modifier], name))
      end

      def element_name(argument, weak: false)
        key = ELEMENT_NAMES.key?(argument.to_s) ? argument : @element
        key = ADVANTAGE[key] if weak && key
        key ? ELEMENT_NAMES.dig(key, @locale) : labels[:element]
      end

      def text_of(nodes)
        saved = @strong
        text = render(nodes).sum("") { |s| s[:text] }
        @strong = saved
        text
      end

      def tidy_text(text)
        text.gsub(/[ \t]*\n[ \t]*/, "\n").gsub(/[ \t]{2,}/, " ")
      end

      # Merge neighbours with the same formatting, tidy whitespace, trim the ends.
      def tidy(segments)
        merged = segments.each_with_object([]) do |s, out|
          if out.any? && out.last.except(:text) == s.except(:text)
            out.last[:text] += s[:text]
          else
            out << s.dup
          end
        end
        merged.each { |s| s[:text] = tidy_text(s[:text]) }
        merged.first[:text] = merged.first[:text].lstrip if merged.any?
        merged.last[:text] = merged.last[:text].rstrip if merged.any?
        merged.reject { |s| s[:text].empty? }
      end
    end
  end
end
