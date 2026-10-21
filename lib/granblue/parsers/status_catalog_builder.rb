# frozen_string_literal: true

module Granblue
  module Parsers
    # Builds the Status catalogue from stored character wiki/game blobs: one status per
    # normalized English name, with one category and, where the game data allows, the game's
    # display status id (ability_detail's `status`, also its icon: status_<id>.png).
    #
    # A name's display id is the curated one, else the one StatusLinker finds in the skills.
    # A name's category comes from, in order:
    # 1. the user-reviewed list (data/statuses/categories.json, CuratedStatusCategories);
    # 2. the game array (buff / debuff / field) its display id sits in, when that's one array;
    # 3. the skill texts: how often the wiki gains the name (buff) or inflicts it (debuff),
    #    over every character that names it (StatusMentions);
    # 4. the category of skills whose ability_detail holds a single category and whose text
    #    gains or inflicts the name;
    # 5. a guess from the name.
    #
    # The game's 10-digit ailment ids can't be paired with the wiki's names (the lists aren't
    # parallel: lanes/board/notes/statuses.md), so the builder no longer writes game_ailment_id.
    class StatusCatalogBuilder
      # The sources a character's statuses come from.
      SOURCE_KINDS = %w[wiki_raw game_raw_en game_raw_jp].freeze

      class << self
        # Every character with stored wiki or game data. Loads only the sources the records
        # come from (wiki_raw_jp is most of their size and isn't one of them);
        # CharacterWikiData reads style_swap to pick the row's own game data.
        def build_all(debug: false)
          characters = Character.with_source(:game_raw_en).or(Character.with_source(:wiki_raw))
          merge_and_persist(characters.select(:id, :granblue_id, :style_swap), overwrite: true, debug: debug)
        end

        # The same merge over the given characters (a relation, or records, unsaved text
        # included), for building a few characters: it adds the statuses they name that the
        # catalogue lacks and fills blank attributes, but never overwrites a category or an
        # id. A subset votes and links differently from the whole table, and build_all's
        # values are the ones every fingerprint was taken with.
        def build_for(characters, debug: false)
          merge_and_persist(characters, overwrite: false, debug: debug)
        end

        private

        def merge_and_persist(characters, overwrite:, debug:)
          StatusList.refresh!
          # The full build first merges rows the current list ties together ("Charm" → Charmed).
          repair(debug) if overwrite
          tallies = {}
          skills = []

          each_character(characters) do |character|
            builder = new(character)
            skills.concat(builder.skills)
            builder.records.each do |record|
              (tallies[Status.normalize_name(record[:name_en])] ||= Tally.new).add(record)
            end
          rescue StandardError => e
            Rails.logger.error "[STATUS_CATALOG] #{character.granblue_id}: #{e.message}"
            puts "[STATUS_CATALOG] #{character.granblue_id}: #{e.message}" if debug
          end

          Persister.new(tallies, skills, overwrite: overwrite, debug: debug).call
        end

        # In a savepoint: a failure rolls the repair back whole and is logged, so it can neither
        # half-merge the catalogue nor fail a deploy's build (the build goes on with the rows as they are).
        def repair(debug)
          Status.transaction(requires_new: true) { ::CharacterSkills::StatusCatalogueRepair.call }
        rescue StandardError => e
          Rails.logger.error "[STATUS_CATALOG] repair failed: #{e.class}: #{e.message}"
          puts "[STATUS_CATALOG] repair failed: #{e.class}: #{e.message}" if debug
        end

        def each_character(characters, &)
          return Array(characters).each(&) unless characters.respond_to?(:find_in_batches)

          # In id order, as find_each: a record merges into the ones before it.
          characters.find_in_batches(batch_size: 200) do |batch|
            Character.preload_sources(batch, kinds: SOURCE_KINDS).each(&)
          end
        end
      end

      # Writes the merged tallies: one status per normalized name.
      class Persister
        ARRAY_SHARE = 0.8

        def initialize(tallies, skills, overwrite:, debug:)
          @tallies = tallies
          @overwrite = overwrite
          @debug = debug
          @curated = CuratedStatusCategories.load
          @links = StatusLinker.new(skills).links.transform_values { |id| StatusName.base_game_id(id) }
          @arrays = game_arrays(skills)
          @skills = skills
          @mentions_by_key = Hash.new { |hash, key| hash[key] = [] }
          skills.each_with_index do |skill, index|
            Array(skill[:resolved]).each { |key, id, vote| @mentions_by_key[key] << [index, id, vote] }
          end
        end

        def call
          counts = { created: 0, updated: 0, failed: 0 }
          existing = existing_statuses

          @tallies.sort.each do |key, tally|
            status = existing[key] || Status.new(name_en: tally.name_en)
            was_new = status.new_record?
            assign(status, key, tally, was_new || @overwrite)
            next unless status.changed?

            save(status, was_new, counts)
          end
          refresh_unmentioned(@tallies.keys, counts) if @overwrite
          warn_unused_curated if @overwrite

          counts.merge(total: Status.count)
        end

        private

        # One bad name (a key clash the lookup didn't see) is logged and counted, not raised,
        # so it can't fail a deploy's build.
        def save(status, was_new, counts)
          Status.transaction(requires_new: true) { status.save! }
          counts[was_new ? :created : :updated] += 1
          puts "[STATUS_CATALOG] #{was_new ? 'created' : 'updated'} #{status.name_en}" if @debug
        rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
          counts[:failed] += 1
          Rails.logger.error "[STATUS_CATALOG] couldn't save #{status.name_en.inspect}: #{e.class}"
          puts "[STATUS_CATALOG] couldn't save #{status.name_en.inspect}: #{e.class}" if @debug
        end

        # Statuses no text mentions any more (a list alias now names them differently) still
        # take what the list says, so they don't keep a stale fallback category or id.
        def refresh_unmentioned(mentioned_keys, counts)
          Status.where.not(name_key: mentioned_keys).find_each do |status|
            key = status.name_key
            listed = StatusList.resolve(status.name_en)
            next if listed.nil? && @curated[key].nil?

            tally = Tally.new.tap { |t| t.add(name_en: status.name_en, listed: listed) }
            assign(status, key, tally, true)
            save(status, false, counts) if status.changed?
          end
        end

        # Curated names no skill text mentions are probably typos in categories.json.
        def warn_unused_curated
          unused = @curated.keys - @tallies.keys
          return if unused.empty?

          Rails.logger.warn "[STATUS_CATALOG] curated names no text mentions: #{unused.sort.join(', ')}"
          puts "[STATUS_CATALOG] curated names no text mentions: #{unused.sort.join(', ')}" if @debug
        end

        def assign(status, key, tally, overwrite)
          game_status_id = display_id(key, tally)
          family, level = Status.split_family_and_level(status.name_en)
          status.family = family
          status.level = level
          fill(status, :wiki_slug, wiki_slug(status, tally), overwrite)
          fill(status, :description, tally.listed&.base_detail, overwrite)
          fill(status, :game_status_id, game_status_id, overwrite)
          fill(status, :variant_kind, tally.variant_kind, overwrite)
          counts = mention_categories(key, game_status_id, listed: tally.listed.present?)
          fill(status, :category, category(key, tally, game_status_id, counts), overwrite)
          status.mixed = mixed?(counts) if overwrite || status.new_record?
        end

        def fill(status, column, value, overwrite)
          status[column] = value if overwrite || status[column].blank?
        end

        def wiki_slug(status, tally)
          (tally.listed&.page.presence || status.name_en).tr(' ', '_')
        end

        # Curated, else the StatusList base entry's id, else the in-skill link (names the list lacks).
        def display_id(key, tally)
          curated = @curated.dig(key, :game_status_id)
          return if curated == CuratedStatusCategories::NO_ID
          return curated if curated
          return tally.listed.base_status_id if tally.listed

          @links[key]
        end

        # The status's usual category (D36: buff/debuff belongs to each skill effect). Curated;
        # else an instant effect (the list's effects table) stays special; else the majority of
        # its effects' own categories (mention_categories; on a tie, the list's table if it's one
        # of them); else the list's table; else, for names the list lacks, the game's array for
        # its linked id, the texts, the single-category skills, the name.
        def category(key, tally, game_status_id, counts)
          listed = tally.listed&.category
          return @curated.dig(key, :category) if @curated.dig(key, :category)
          return 'special' if listed == 'special'

          usual(counts.transform_values(&:first), listed) || listed ||
            (game_array(game_status_id) unless tally.listed) || tally.category || StatusCatalogBuilder.infer_category(key)
        end

        def usual(counts, listed)
          return if counts.empty?

          top = counts.values.max
          leaders = counts.select { |_, n| n == top }.keys
          return leaders.first if leaders.one?

          listed if leaders.include?(listed)
        end

        # Its effects split: both buff and debuff, the minority side backed by the game or by two
        # mentions (Hostility Up: a buff for Seox, a self-inflicted debuff for Clarisse (Light)).
        def mixed?(counts)
          buff, debuff = counts.values_at('buff', 'debuff')
          return false unless buff && debuff

          minority = [buff, debuff].min_by(&:first)
          minority.first >= 2 || minority.last.positive?
        end

        # Names the list lacks: their linked id, else its 4-digit icon family.
        def game_array(id)
          id && (@arrays[id] || @arrays[StatusName.base_game_id(id)])
        end

        # A listed status: the game's arrays in the skills that name it (mention_game_counts). A
        # 4-digit icon family is shared by unrelated statuses (6156: Charmed (Local), Allure).
        # Each mention's category, as its effect gets it: the same CharacterSkills::EffectCategory the
        # effect parser uses (game in that skill, curated, the text rule), so the usual category and
        # `mixed` can't disagree with the effects. → { category => [mentions, of which game-backed] }.
        # Skills that list the id without naming the status (another status sharing the icon) don't count.
        def mention_categories(key, base_id, listed:)
          counts = Hash.new { |hash, category| hash[category] = [0, 0] }
          curated = @curated.dig(key, :category)
          @mentions_by_key[key].each do |index, id, vote|
            family = StatusName.base_game_id(base_id) if !listed && base_id.present?
            game = { details: @skills[index][:details], ids: [id, base_id], family: family }
            result = ::CharacterSkills::EffectCategory.call(game: game, vote: vote, curated: curated)
            next if result.category.nil?

            counts[result.category][0] += 1
            counts[result.category][1] += 1 if result.source == :game
          end
          counts
        end

        # display id (exact, and its 4-digit base) → its category, when the game puts it in one
        # array at least ARRAY_SHARE of the time (1463 Hostility Up: 24 buff, 1 debuff).
        def game_arrays(skills)
          seen = Hash.new { |hash, id| hash[id] = Hash.new(0) }
          skills.each do |skill|
            skill[:details].each do |detail|
              seen[detail[:id]][detail[:category]] += 1
              seen[StatusName.base_game_id(detail[:id])][detail[:category]] += 1
            end
          end
          seen.filter_map { |id, counts| (category = majority(counts)) && [id, category] }.to_h
        end

        def majority(counts)
          return if counts.empty?

          category, count = counts.max_by { |c, n| [n, c] }
          category if count >= ARRAY_SHARE * counts.values.sum
        end

        # The status per name key (unique, so one each).
        def existing_statuses
          Status.named(@tallies.keys).order(:created_at, :id).each_with_object({}) do |status, by_key|
            by_key[status.name_key] ||= status
          end
        end
      end

      # The votes for one status (a name without its variant number) across characters. The
      # spelling kept for a new status is the most common one (ties: the first in sort order).
      class Tally
        def initialize
          @spellings = Hash.new(0)
          @text = Hash.new(0)
          @game = Hash.new(0)
          @variants = Hash.new(0)
        end

        def add(record)
          @spellings[record[:name_en]] += 1
          @text[record[:text_vote]] += 1 if record[:text_vote]
          @game[record[:game_vote]] += 1 if record[:game_vote]
          @variants[record[:variant_evidence]] += 1 if record[:variant_evidence]
          @listed = record[:listed] if @listed.nil?
        end

        # What gbf.wiki's Module:StatusList says about the status (StatusList::Resolution), if anything.
        attr_reader :listed

        # What the family's numbers mean (turns | level | uses), when its mentions carry any.
        def variant_kind
          StatusName.family_kind(@variants) if @variants.any?
        end

        # The numbered mentions' evidence, for the review list: { uses:, turns:, other_turns:, plain: }.
        def variant_evidence
          @variants.dup
        end

        def name_en
          @spellings.min_by { |spelling, count| [-count, spelling] }.first
        end

        def category
          winner(@text) || winner(@game)
        end

        private

        def winner(votes)
          return if votes.empty?

          top = votes.values.max
          leaders = votes.select { |_, count| count == top }.keys
          leaders.first if leaders.one?
        end
      end

      def self.infer_category(name)
        normalized = name.to_s.downcase

        if normalized.match?(/lowered|down|delay|petrified|paralyzed|poison|charmed|sleep|blind|fear/)
          'debuff'
        elsif normalized.include?('field')
          'field'
        else
          'buff'
        end
      end

      def initialize(character)
        @data = CharacterWikiData.new(character)
      end

      # Per skill with text: its status mentions (named by status, without the variant number)
      # and the game's ability_detail entries ({ category:, id: }), for StatusLinker.
      def skills
        @skills ||= skill_keys.map do |skill_key|
          mentions = StatusMentions.in(params["#{skill_key}_effdesc"] || params["#{skill_key}_desc"])
          resolved = mentions.map { |mention| StatusName.resolve(mention.name) }
          { mentions: mentions.zip(resolved).map { |mention, r| mention.dup.tap { |m| m.name = r.name } },
            raw_mentions: mentions,
            # [normalized status name, exact display id, text vote] per mention, for its category.
            resolved: resolved.zip(mentions).map { |r, m| [Status.normalize_name(r.name), r.game_status_id, m.vote] },
            details: game_details(data.game_action(skill_key)) }
        end
      end

      # One record per mention: { name_en:, text_vote:, game_vote:, variant_evidence: }.
      def records
        by_skill_records + fallback_wiki_records
      end

      private

      attr_reader :data

      def by_skill_records
        skills.flat_map do |skill|
          game_category = single_category(skill[:details])

          skill[:raw_mentions].filter_map do |mention|
            next if mention.name.blank?

            resolved = StatusName.resolve(mention.name)
            { name_en: resolved.name, text_vote: mention.vote, game_vote: mention.vote && game_category,
              variant_evidence: variant_evidence(resolved.variant, mention.params), listed: resolved.resolution }
          end
        end
      end

      # Names mentioned anywhere else (e.g. only in a support skill's condition): no votes.
      def fallback_wiki_records
        StatusMentions.in(params.values.join("\n")).filter_map do |mention|
          next if mention.name.blank?

          resolved = StatusName.resolve(mention.name)
          { name_en: resolved.name, listed: resolved.resolution }
        end
      end

      def variant_evidence(variant, mention_params)
        return if variant.nil?

        kind = StatusName.mention_kind(variant, mention_params)
        return kind.to_sym if kind
        return :other_turns if mention_params.to_h['t'].to_s.match?(/\A\d+(?:\.\d+)?\s*t/i)

        :plain
      end

      def game_details(game_action)
        details = game_action&.dig('ability_detail')
        return [] unless details.is_a?(Hash)

        details.flat_map do |category, entries|
          Array(entries).filter_map do |entry|
            { category: normalize_category(category), id: entry['status'].to_s } if entry.is_a?(Hash) && entry['status'].present?
          end
        end
      end

      def single_category(details)
        categories = details.map { |detail| detail[:category] }.uniq
        categories.first if categories.one?
      end

      def normalize_category(category)
        case category.to_s
        when /debuff/i then 'debuff'
        when /field/i then 'field'
        else 'buff'
        end
      end

      def skill_keys
        params.keys.grep(/\A(?:a\d+[a-z]?|ougi\d*|sa\d*)_(?:effdesc|desc)\z/).map do |key|
          key.sub(/_(?:effdesc|desc)\z/, '')
        end.uniq
      end

      def params
        data.params
      end
    end
  end
end
