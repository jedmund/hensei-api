# frozen_string_literal: true

module CharacterSkills
  # Turns a character skill's wiki description into display segments, the way
  # WeaponSkills::WikiMarkup does for weapon skills, with two segment kinds of its own:
  #
  #   { text: "Toxicosis", effect: 2 }            a {{status}} mention; effect is the ordinal of
  #                                               the skill effect parsed from it (EffectParser)
  #   { text: "Scythe of Execution", skill: true } a {{CharacterSkill2}}-style skill reference
  #
  # A mention with no matching effect keeps the plain status tooltip (amount, duration).
  # Pure apart from skill_name, the caller's lookup for referenced skills.
  module DescriptionMarkup
    module_function

    # effects: the version's parsed effects (EffectParser#parse). skill_name: a callable
    # (kind, page, position) → the referenced skill's name or nil; kind is "ability" or
    # "support", and a blank page means the character itself.
    def segments(text, effects: [], skill_name: nil)
      return [] if text.blank?

      Renderer.new(effects: effects, skill_name: skill_name)
              .render_all(WeaponSkills::WikiMarkup::Parser.new(text).parse)
    end

    class Renderer < WeaponSkills::WikiMarkup::Renderer
      SKILL_TEMPLATES = {
        "characterskill" => "ability", "characterskill2" => "ability",
        "charactersupportskill" => "support", "charactersupportskill2" => "support"
      }.freeze

      STATUS_RAW = /\A\{\{status\|([^|}]+)/i

      def initialize(effects:, skill_name:)
        super(element: nil, locale: :en)
        @status_effects = effects.select { |effect| effect[:raw].to_s.match?(STATUS_RAW) }
                                 .sort_by { |effect| effect[:ordinal].to_i }
        @skill_name = skill_name
      end

      private

      def render_template(parts)
        name = text_of(parts.first).strip.downcase
        positional, named = split_args(parts.drop(1))
        case name
        when "status" then status(positional, named)
        when *SKILL_TEMPLATES.keys then skill_reference(SKILL_TEMPLATES[name], positional, named)
        when "chainburst" then chain_burst(positional)
        when "petrified" then [segment("Petrified")]
        when "revitalize", "refresh" then healing(name.capitalize, named)
        else super
        end
      end

      def status(positional, named)
        text = text_of(positional[0]).strip
        effect = take_effect(text)
        return with_tooltip([segment(text)], status_tooltip(named)) if effect.nil?

        [segment(text).merge(effect: effect[:ordinal])]
      end

      # Effects are parsed from the same text in the same order, so the next unclaimed
      # effect with this name is the one this mention produced.
      def take_effect(text)
        key = normalize(text)
        index = @status_effects.index { |effect| normalize(effect[:raw][STATUS_RAW, 1]) == key }
        index && @status_effects.delete_at(index)
      end

      def normalize(name) = name.to_s.squish.downcase

      def skill_reference(kind, positional, named)
        page = text_of(named["page"] || positional[0]).strip
        position = text_of(named["no"] || positional[1]).strip.to_i
        name = @skill_name&.call(kind, page, position) if position.positive?
        name ||= fallback_skill_name(kind, page, position)
        [segment(name).merge(skill: true)]
      end

      def fallback_skill_name(kind, page, position)
        label = kind == "support" ? "support skill" : "skill"
        label = "#{label} #{position}" if position.positive?
        page.present? ? "#{page}'s #{label}" : label.capitalize
      end

      def chain_burst(positional)
        element = text_of(positional[0]).strip
        count = text_of(positional[1]).strip
        [segment("(#{[element.presence, count.presence && "#{count}-chain"].compact.join(', ')})")]
      end

      def healing(label, named)
        amount = tooltip_text(named["a"])
        cap = tooltip_text(named["cap"])
        with_tooltip([segment(label)], [amount, cap && "Healing cap: #{cap}"].compact.join(" · ").presence)
      end
    end
  end
end
