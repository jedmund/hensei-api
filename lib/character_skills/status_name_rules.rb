# frozen_string_literal: true

module CharacterSkills
  # The display-name rules for statuses (D32, D42): base/present forms, applied in order to a name's
  # main words (bracketed modifiers and a trailing variant number stay as they are). Each rule maps
  # words to words and may flag a result that reads oddly; StatusNameRule.propose runs them, and the
  # review (decision N) lists them for approval. Nothing is renamed until data/statuses/aliases.json
  # holds the approved renames.
  module StatusNameRules
    Rule = Struct.new(:id, :pattern, :example, :note, :apply, keyword_init: true)

    ELEMENTS = %w[fire water earth wind light dark].freeze

    # Replaces every `from` word with `to`, flagging an adverb or element right before it.
    def self.swap(from, to, position_flag: true)
      lambda do |words, _context|
        flags = []
        out = words.each_with_index.map do |word, i|
          next word unless word.casecmp?(from)

          flags << "adverb before #{to} (#{words[i - 1]})" if i.positive? && words[i - 1].match?(/ly\z/i)
          flags << "#{to} right after an element (#{words[i - 1]})" if i.positive? && ELEMENTS.include?(words[i - 1].downcase)
          flags << "#{to} isn't the last word" if position_flag && i < words.size - 1
          to
        end
        [out, flags]
      end
    end

    # Blinded → Blind, Hyped → Hype, Petrified → Petrify, Stunned → Stun.
    def self.participle_stems(word)
      stems = [word[0...-2], word[0...-1]]
      stems << "#{word[0...-3]}y" if word.end_with?('ied')
      stems << word[0...-3] if word.match?(/([b-df-hj-np-tv-z])\1ed\z/)
      stems.uniq
    end

    PARTICIPLE = lambda do |words, context|
      last = words.last.to_s
      return [words, []] unless last.match?(/[a-z][^e]ed\z/) && !last.casecmp?('boosted') && !last.casecmp?('lowered')

      stem = participle_stems(last).find do |candidate|
        context[:vocabulary].include?(Status.normalize_name([*words[0...-1], candidate, context[:modifiers]].compact.join(' '))) ||
          context[:vocabulary].include?(Status.normalize_name([*words[0...-1], candidate].join(' ')))
      end
      stem ? [[*words[0...-1], stem], []] : [words, ["\"#{last}\" kept: no base form among wiki names"]]
    end

    RULES = [
      Rule.new(id: 'boosted_to_up', pattern: '"Boosted" becomes "Up"', example: 'ATK Boosted (Stackable) → ATK Up (Stackable)',
               note: 'Flagged when it lands on a debuff or after an adverb ("ATK Sharply Up").', apply: swap('boosted', 'Up')),
      Rule.new(id: 'lowered_to_down', pattern: '"Lowered" becomes "Down"', example: 'DEF Lowered → DEF Down',
               note: 'Flagged on a buff ("Dark DMG Lowered" is less DMG taken) or right after an element ("Fire Lowered").',
               apply: swap('lowered', 'Down')),
      Rule.new(id: 'participle_to_base', pattern: 'a last word ending in "-ed" becomes its base form, when the wiki also uses that name',
               example: 'Blinded → Blind; Charmed (Local) → Charm (Local)',
               note: 'Kept and flagged when the wiki never uses the base form (Paralyzed, Petrified).', apply: PARTICIPLE)
    ].freeze
  end
end
