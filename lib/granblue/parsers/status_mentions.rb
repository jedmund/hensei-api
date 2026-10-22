# frozen_string_literal: true

module Granblue
  module Parsers
    # The {{status|…}} mentions in a skill text, each with the rule that says how the text uses it
    # (CharacterSkills::StatusVerbRules, D40: an ordered list, first match wins): "Gain X" → buff;
    # "Inflict X on a foe", "Self-inflict X", "Raise all foes' X lvl" → debuff; "(X to the field.)"
    # → field; "When X is in effect", "Consumes X" → no vote. A buff given to a foe ("All foes gain
    # ATK Up 2") is still a buff.
    class StatusMentions
      # vote: buff | debuff | field | nil; kind: how the text uses it (gain | inflict | self_inflict |
      # field | condition | other); params: the template's named parameters (t=, n=, a=…).
      # rule: the CharacterSkills::StatusVerbRules rule that decided it (its id is reported in the review).
      Mention = Struct.new(:name, :vote, :params, :kind, :rule)

      STATUS = /\{\{status\|([^}]+)\}\}/i
      INNER_TEMPLATE = /\{\{[^{}]*\}\}/
      # A template parameter boundary (|des1=…) ends a clause too: InfoDes keeps each skill level's text in
      # its own parameter. A bare | doesn't ({{tt|[[…]]|…}} stays one piece).
      PARAM_BREAK = /\|\w+=/
      CLAUSE_BREAK = %r{<br\s*/?>|\.\s|\n|;|:|\(|\)|\|\w+=}i

      def self.in(text)
        new(text).to_a
      end

      def initialize(text)
        @text = text.to_s
      end

      def to_a
        @text.to_enum(:scan, STATUS).map do
          match = Regexp.last_match
          name = clean_name(match[1])
          rule = rule_for(@text[0...match.begin(0)], @text[match.end(0)..], StatusList.resolve(name)&.category)
          Mention.new(name, rule.category, params(match[1]), rule.kind, rule)
        end
      end

      private

      def params(inner)
        inner.split('|').drop(1).each_with_object({}) do |part, params|
          key, value = part.split('=', 2)
          params[key.to_s.strip.downcase] = value.to_s.strip if value
        end
      end

      def clean_name(inner)
        inner.split('|').first.to_s.strip
      end

      # The first matching rule (CharacterSkills::StatusVerbRules, D40) for the clause before the
      # mention, the text right after it, and the wiki list's table for the status.
      def rule_for(before, after, listed)
        clause = strip_templates(before).split(CLAUSE_BREAK, -1).last.to_s.downcase
        rest = strip_templates(after).split(PARAM_BREAK, 2).first.to_s
        ::CharacterSkills::StatusVerbRules.match(clause, rest.downcase, listed)
      end

      # Drops complete templates ({{status|…}}, {{tt|…}}) so their text doesn't read as the
      # clause, leaving an unclosed wrapper such as "{{InfoDes|num=0|des=" in place.
      def strip_templates(text)
        previous = nil
        text = text.gsub(INNER_TEMPLATE, '') until previous == (previous = text)
        text
      end
    end
  end
end
