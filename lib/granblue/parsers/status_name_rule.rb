# frozen_string_literal: true

module Granblue
  module Parsers
    # The display-name rule for statuses (D32): runs CharacterSkills::StatusNameRules (D42) on a
    # name's main words. Used to propose renames for review (granblue:status_rename_list); the
    # approved result is data/statuses/aliases.json, which the build applies (StatusAliases).
    module StatusNameRule
      Proposal = Struct.new(:from, :to, :flags, :rules)

      module_function

      # vocabulary: normalized names known to the wiki (to confirm a participle's base form).
      # → Proposal(from, to, flags, rules: the ids of CharacterSkills::StatusNameRules that changed it).
      def propose(name, vocabulary: Set.new)
        main, modifiers = split_modifiers(name)
        words = main.split
        flags = []
        applied = []
        ::CharacterSkills::StatusNameRules::RULES.each do |rule|
          changed, rule_flags = rule.apply.call(words, vocabulary: vocabulary, modifiers: modifiers)
          applied << rule.id if changed != words
          flags.concat(rule_flags)
          words = changed
        end
        Proposal.new(name, [words.join(' '), modifiers].compact.join(' '), flags, applied)
      end

      # → [main words, modifiers]: bracketed modifiers and a trailing variant number stay as they are.
      def split_modifiers(name)
        name = name.to_s.squish
        index = name.index(' (') || name.index(/ \d+\z/)
        index ? [name[0...index], name[(index + 1)..]] : [name, nil]
      end

      def participle_stems(word)
        ::CharacterSkills::StatusNameRules.participle_stems(word)
      end
    end
  end
end
