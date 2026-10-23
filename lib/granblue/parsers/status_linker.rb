# frozen_string_literal: true

module Granblue
  module Parsers
    # Links wiki status names to the game's display status ids.
    #
    # The game lists a skill's statuses in ability_detail, grouped by category, each with a
    # display id (`status`, e.g. "1020" or the icon variant "1020_13"). The wiki names them in
    # the skill text. Within one skill, a name the text gains (or inflicts) pairs with the
    # skill's buff (or debuff) id when it's the only one left on both sides: names already
    # linked are taken out of every skill, round after round, until nothing new links. A link
    # needs LINK_SHARE of its votes to agree.
    #
    # A name links to a base id ("1020"); when its votes settle on one variant of that base
    # ("1019_0_40" for 40% DMG Cut), it links to the variant. One id can carry several names
    # (the game reuses icons), but a name never gets two ids.
    class StatusLinker
      LINK_SHARE = 0.8
      MAX_ROUNDS = 10
      SIDES = { 'buff' => 'buff', 'debuff' => 'debuff' }.freeze

      # skills: [{ mentions: [StatusMentions::Mention], details: [{ category:, id: }] }]
      def initialize(skills)
        @groups = skills.flat_map { |skill| groups_for(skill) }
      end

      # → { normalized name => display id }
      def links
        @links ||= variants_for(base_links)
      end

      private

      # One group per skill and side: the names it applies on that side, and its ids there.
      def groups_for(skill)
        SIDES.keys.filter_map do |category|
          names = skill[:mentions].select { |mention| mention.vote == category }
                                  .map { |mention| Status.normalize_name(mention.name) }.uniq
          ids = skill[:details].select { |detail| detail[:category] == category }.map { |detail| detail[:id] }.uniq
          { names: names, ids: ids } if names.any? && ids.any?
        end
      end

      def base_links
        linked = {}
        MAX_ROUNDS.times do
          found = accepted(round_votes(linked)).except(*linked.keys)
          break if found.empty?

          linked.merge!(found)
        end
        linked
      end

      def round_votes(linked)
        votes = Hash.new { |hash, name| hash[name] = Hash.new(0) }
        @groups.each do |group|
          taken = group[:names].filter_map { |name| linked[name] }
          names = group[:names] - linked.keys
          bases = group[:ids].map { |id| base(id) }.uniq - taken
          votes[names.first][bases.first] += 1 if names.one? && bases.one?
        end
        votes
      end

      def accepted(votes)
        votes.each_with_object({}) do |(name, counts), found|
          id, count = counts.max_by { |candidate, n| [n, candidate] }
          found[name] = id if count >= LINK_SHARE * counts.values.sum
        end
      end

      def variants_for(linked)
        votes = Hash.new { |hash, name| hash[name] = Hash.new(0) }
        @groups.each do |group|
          group[:names].each do |name|
            next unless linked.key?(name)

            ids = group[:ids].select { |id| base(id) == linked[name] }
            votes[name][ids.first] += 1 if ids.one?
          end
        end
        linked.to_h do |name, base_id|
          variant = accepted(name => votes[name])[name] if votes[name].any?
          [name, variant || base_id]
        end
      end

      def base(id)
        StatusName.base_game_id(id)
      end
    end
  end
end
