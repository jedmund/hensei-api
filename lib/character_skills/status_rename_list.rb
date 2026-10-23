# frozen_string_literal: true

module CharacterSkills
  # Proposes the status renames and merges the naming rule (D32, Granblue::Parsers::StatusNameRule)
  # implies, for the user's review. Nothing is written to the catalogue: the approved result is
  # copied to data/statuses/aliases.json.
  #
  # statuses: [{ name:, category:, effects:, wiki_label: }] (wiki_label: the wiki's own display name); mentions: { normalized wiki name => count };
  # groups: extra alias groups to merge ([[name, …], …], e.g. "Counter on DMG"/"Counters on DMG").
  # Each merged group shows as the transformed spelling with the most wiki mentions.
  class StatusRenameList
    Group = Struct.new(:canonical, :statuses, :flags, :categories, :rules, keyword_init: true)

    # vocabulary: extra normalized names the wiki uses (raw spellings, the status list's names).
    def initialize(statuses:, mentions:, groups: [], vocabulary: Set.new)
      @statuses = statuses
      @mentions = mentions
      @extra = groups
      vocabulary = vocabulary | mentions.keys.to_set | statuses.to_set { |s| Status.normalize_name(s[:name]) }
      @proposals = statuses.to_h { |s| [s[:name], Granblue::Parsers::StatusNameRule.propose(s[:name], vocabulary: vocabulary)] }
    end

    # → [Group] for every status whose name changes or that merges with another.
    def groups
      @groups ||= clusters.filter_map { |names| group_for(names) }
                          .sort_by { |group| [group.flags.empty? && group.categories.one? ? 1 : 0, group.canonical.downcase] }
    end

    # The aliases.json entries the groups imply: every member spelled differently from its status.
    def aliases
      groups.flat_map do |group|
        group.statuses.reject { |m| m[:name] == group.canonical }.map do |m|
          { 'wiki_name' => m[:name], 'name_en' => group.canonical, 'reason' => 'D32 naming rule' }
        end
      end
    end

    private

    def group_for(names)
      members = names.filter_map { |name| @statuses.find { |s| s[:name] == name } }
      return if members.empty?

      canonical = canonical_for(members)
      return if members.one? && members.first[:name] == canonical && @proposals[canonical].flags.empty?

      flags = (members.flat_map { |m| @proposals[m[:name]].flags } + direction_flags(members)).uniq
      Group.new(canonical: canonical, statuses: members, flags: flags, categories: members.map { |m| m[:category] }.uniq,
                rules: members.flat_map { |m| @proposals[m[:name]].rules }.uniq)
    end

    # "Dark DMG Lowered" is a buff (less DMG taken): "Down" on a buff, or "Up" on a debuff
    # ("Break Boosted"), reads the wrong way round.
    def direction_flags(members)
      members.filter_map do |m|
        words = @proposals[m[:name]].to.split
        if m[:category] == 'buff' && words.include?('Down') && m[:name].match?(/\blowered\b/i)
          'Down on a buff'
        elsif m[:category] == 'debuff' && words.include?('Up') && m[:name].match?(/\bboosted\b/i)
          'Up on a debuff'
        end
      end
    end

    def mentions_of(name)
      @mentions[Status.normalize_name(name)].to_i
    end

    # Names that end up as one status: the same transformed name, or an extra group.
    def clusters
      parent = {}
      find = ->(x) { parent[x] == x ? x : (parent[x] = find.call(parent[x])) }
      union = ->(a, b) { parent[find.call(a)] = find.call(b) }
      @statuses.each { |s| parent[s[:name]] = s[:name] }
      by_key = @statuses.group_by { |s| Status.normalize_name(@proposals[s[:name]].to) }
      by_key.each_value { |members| members.each_cons(2) { |a, b| union.call(a[:name], b[:name]) } }
      @extra.each do |names|
        present = names.select { |name| parent.key?(name) }
        present.each_cons(2) { |a, b| union.call(a, b) }
      end
      parent.keys.group_by { |name| find.call(name) }.values
    end

    def canonical_for(members)
      forms = members.group_by { |m| @proposals[m[:name]].to }
      forms.max_by { |form, ms| [ms.sum { |m| mentions_of(m[:name]) }, form] }.first
    end
  end
end
