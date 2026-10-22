# frozen_string_literal: true

module CharacterSkills
  # How a skill text's words put a {{status|…}} on a side (D40): an ordered list of plain rules,
  # the first that matches decides. Each reads the clause before the mention (`before`, lower case,
  # templates removed), the text right after it (`after`) and, for the few rules that need it, the
  # wiki status list's table for the status (`listed`: buff | debuff | field | special | nil). A rule's category is what the effect
  # gets when the game's own data doesn't decide it (EffectParser): buff, debuff, field, or nil (no
  # vote: the status is named but not applied, e.g. "When X is in effect", "Consumes X").
  module StatusVerbRules
    Rule = Struct.new(:id, :pattern, :example, :category, :scope, :kind, :matcher, keyword_init: true) do
      def match?(before, after, listed = nil) = matcher.call(before, after, listed)
    end

    COUNTER_AFTER = /\A\s*(?:lvl|level|stacks?)\b/
    FOE = /\bfoe|\benemy|\benemies|\bfoes\b/
    CONDITION = /\b(?:remove|removes|dispel|cure|clear|nullif\w*|negate|immun\w*|resist\w*|cancel|prevent|against|
                   with|while|if|when|during|has|have|per|for\ each|based\ on|lose|upon|no\ longer|unleash|extend|order)\b/x
    COUNTER_VERB = /\b(?:raise|raises|restore|restores|reset|resets|refill|refills)\b/
    # A verb that applies the status. After a condition word it decides ("If successful, inflict X").
    APPLY_VERB = /\b(?:inflict\w*|gain|gains|grant|grants|give|gives|bestow)\b/

    # The text after the last match of `pattern` in `text` (nil when there's none).
    def self.after_last(text, pattern)
      last = nil
      text.scan(pattern) { last = Regexp.last_match }
      last && text[last.end(0)..]
    end

    def self.rule(id, pattern, example, category, scope, kind, &matcher)
      Rule.new(id: id, pattern: pattern, example: example, category: category, scope: scope, kind: kind, matcher: matcher)
    end

    RULES = [
      rule('self_inflict', 'the clause says "self-inflict"', 'Self-inflict Overheated.', 'debuff', 'caster', 'self_inflict') do |b, _|
        b.include?('self-inflict')
      end,
      rule('foe_counter', "raise or increase a foe's counter (lvl / stacks)", "Raise all foes' Tuning lvl by 1.", 'debuff', 'foes',
           'inflict') do |b, a|
        b.match?(/\b(?:raise|raises|increase|increases)\b/) && b.match?(FOE) && a.match?(COUNTER_AFTER)
      end,
      rule('set_on_foe', 'set it on a foe', 'Set a Flower Bud on a foe.', 'debuff', 'foes', 'inflict') do |b, a|
        b.match?(/\bsets?\b/) && (b.match?(FOE) || a.match?(/\A[^.;(<]*?\bon (?:a |an |all |the )?(?:foes?|enem)/))
      end,
      rule('consume', 'consume, use or spend it (spending, not applying)', 'Consumes 1 Dissolution.', nil, '-', 'condition') do |b, _|
        b.match?(/\b(?:consume|consumes|consuming|use|uses|spend|spends)\b/)
      end,
      rule('starts_battle', 'starts or begins battle with it', "Starts battle with 3 Bridal Bullet.", 'buff', 'caster', 'gain') do |b, _|
        b.match?(/\b(?:starts?|begins?) (?:the )?battle with\b/)
      end,
      rule('switch_to', 'switch, shift or change to it (a mode or stance)', 'Switch to Supplication mode.', 'buff', 'caster',
           'gain') do |b, _|
        b.match?(/\b(?:switch(?:es)?|shifts?|changes?(?: strategy)?) to\s*\z/)
      end,
      # caster_counter's sub-rules (D44): a counter that's counted or checked, and counters the wiki
      # list files under debuffs (they sit on a foe: Thunderstruck, Glaciate), don't vote; the status
      # keeps its usual category.
      rule('counter_checked', 'raise/restore/reset/refill, then "based on", "number of", "for each" or "with" (counted, not raised)',
           "Restore all allies' HP based on Hyped lvl.", nil, '-', 'condition') do |b, _|
        rest = after_last(b, COUNTER_VERB)
        rest&.match?(/\b(?:based on|number of|for each|with)\b/)
      end,
      rule('foe_held_counter', "raise/restore/reset/refill a counter the wiki list files under debuffs (it sits on a foe)",
           'Raise Thunderstruck lvl by 1.', nil, '-', 'condition') do |b, _, listed|
        listed == 'debuff' && b.match?(COUNTER_VERB) && !b.match?(FOE) && !b.match?(/\b(?:when|while|if|upon)\b/)
      end,
      rule('caster_counter', "raise, restore, reset or refill the caster's or allies' counter", 'Raise Rev level by 1.', 'buff',
           'caster / allies', 'gain') do |b, _|
        b.match?(COUNTER_VERB) && !b.match?(FOE) && !b.match?(/\b(?:when|while|if|upon)\b/)
      end,
      rule('counter_rises', 'its lvl rises or it swells', 'Body Heat lvl rises by 1.', 'buff', 'caster', 'gain') do |b, a|
        !b.match?(/\b(?:when|while|if|upon|based on)\b/) && a.match?(/\A\s*(?:(?:lvl|level)\s+(?:rises|increases|goes up)|swells)\b/)
      end,
      # condition's sub-rule (D44): immunity to a status, or resisting/nullifying it, names a debuff.
      rule('immune', 'immune, resist, nullify, negate, cancel or prevent it', 'Immune to Poisoned.', 'debuff', '-', 'condition') do |b, _|
        last = nil
        b.scan(CONDITION) { last = Regexp.last_match }
        last && last[0].match?(/\A(?:immun|resist|nullif|negate|cancel|prevent)/) && !b[last.end(0)..].match?(APPLY_VERB)
      end,
      rule('condition', 'named in a condition (when, while, if, against, with, remove, …)', 'When Lucent Refuge is in effect: …',
           nil, '-', 'condition') do |b, _|
        # An apply verb after the last condition word decides instead (D44): "If successful, inflict X"
        # falls to inflict, "If successful, all allies gain X" to gain.
        b.match?(CONDITION) && !after_last(b, CONDITION).to_s.match?(APPLY_VERB)
      end,
      rule('inflict', 'the clause says "inflict"', 'Inflict DEF Down on a foe.', 'debuff', 'foes', 'inflict') do |b, _|
        b.match?(/\binflict/)
      end,
      rule('gain', 'the clause says gain, grant, receive or give', 'All allies gain DEF Up.', 'buff', 'caster / allies', 'gain') do |b, _|
        b.match?(/\b(?:gain|gains|grant|grants|receives?|give|bestow)\b/)
      end,
      rule('foe_subject', 'the clause is about a foe (no verb)', "Raise foe's Thunderstruck lvl.", 'debuff', 'foes', 'inflict') do |b, _|
        b.match?(FOE)
      end,
      rule('ally_subject', 'the clause is about the caster or allies (no verb)', 'Caster: Shield.', 'buff', 'caster / allies', 'gain') do |b, _|
        b.match?(/\b(?:ally|allies|caster|party)\b/)
      end,
      rule('to_the_field', 'followed by "to the field"', '(Utopia to the field.)', 'field', 'field', 'field') do |_, a|
        a.match?(/\A[^.;(<]*?\bto the (?:\[\[[^\]|]*\|)?field\b/)
      end,
      rule('on_a_foe', 'followed by "on a foe"', 'Sic Dorrie on a foe.', 'debuff', 'foes', 'inflict') do |_, a|
        a.match?(/\A[^.;(<]*?\bon (?:a |an |all |the |random )?(?:foes?|enem(?:y|ies))\b/)
      end,
      rule('to_an_ally', 'followed by "to an ally"', 'Grant Freigeist to another Dark ally.', 'buff', 'allies', 'gain') do |_, a|
        a.match?(/\A[^.;(<]*?\bto (?:a |an |all |another |the )?(?:[a-z]+ )?all(?:y|ies)\b/)
      end
    ].freeze

    OTHER = Rule.new(id: 'other', pattern: 'no rule matches', example: '', category: nil, scope: '-', kind: 'other',
                     matcher: ->(*) { true })

    # The first rule that matches (OTHER when none does).
    def self.match(before, after, listed = nil)
      RULES.find { |rule| rule.match?(before, after, listed) } || OTHER
    end
  end
end
