# frozen_string_literal: true

module WeaponSkills
  module Build
    # The structure compiler: a weapon's stored wiki sources in, its skill slots and versions
    # out. Pure: it reads only the source store (no network, no database writes) and gives the
    # same answer whatever order the sources were stored in.
    #
    #   Structure.call(weapon, store:)  # → [slots, versions, warnings]
    #
    # weapon: anything with granblue_id, wiki_en and name_en.
    #
    # The steps are today's import, run from scratch instead of on top of the database:
    #   1. The structural parse (WeaponParser#persist_skills_from_wiki_raw): the page (or the
    #      page it transcludes) merged with its series template, now with the template's level
    #      defaults (Structure::Wikitext).
    #   2. The expansion repair (ExpandedWeaponSkillImporter.repair_weapon), for series-template
    #      pages and for pages whose parse leaves template syntax in a skill name. Expanded
    #      skills match parsed tiers by name; the rest become new slots after the last parsed
    #      position, and tiers with template syntax in their names are dropped. A new slot
    #      takes the gate of the dropped tier whose name it fills in ("{{WeaponElement|…}}'s
    #      Majesty" → "Water's Majesty", lvl 120).
    #   3. Key-determined pages (page_kind "key_determined") skip the repair: their expansion
    #      lists every key option, and the key resolver owns those.
    #
    # Versions carry derived classification only; overrides are the overlay's.
    module Structure
      Version = WeaponSkills::BuildResult::Version
      Slot = WeaponSkills::BuildResult::Slot
      Parser = Granblue::Parsers::WeaponSkillDescriptionParser
      GARBLED = /[{}]/
      WILDCARD = "\u0001" # not "\0": String#strip removes NULs
      KEY_DETERMINED = "key_determined"
      SERIES_TEMPLATE = "series_template"

      module_function

      def call(weapon, store:)
        warnings = []
        page = fetch(store, "wiki_raw", weapon.wiki_en)
        return [[], [], ["#{weapon.granblue_id}: no stored wiki_raw for #{weapon.wiki_en.inspect}"]] unless page

        fields = page_fields(weapon, page.body, store, warnings)
        slots = Tiers.slots(fields)
        page_kind = page.page_kind.to_s

        expanded_rows = nil
        needed = page_kind == SERIES_TEMPLATE || garbled?(slots)
        # a tier with no text of its own reads the expansion's (Skill#description_en, by name)
        if needed || untexted?(slots)
          expanded = expansion(store, weapon.wiki_en, page.body)
          if expanded
            expanded_rows = Expanded.rows(expanded.body)
          elsif needed
            warnings << "#{weapon.granblue_id}: needs its expansion, none stored"
          end
        end
        mode = if page_kind == KEY_DETERMINED then :key
               elsif needed then :repair
               else :text
               end

        versions = build_versions(weapon, fields, page.body, slots, expanded_rows.presence, mode: mode)
        versions.sort_by!(&:identity)
        slots_out = versions.map(&:position).uniq.map { |p| Slot.new(weapon_granblue_id: weapon.granblue_id, position: p) }
        [slots_out, versions, warnings]
      end

      def fetch(store, kind, key)
        return nil if key.blank?

        store.fetch(kind, key)
      rescue WeaponSkills::SourceStore::SourceMissing
        nil
      end

      # The page that holds the skill fields (WeaponParser#skill_source_text), parsed and merged
      # with its series template.
      def page_fields(weapon, raw, store, warnings)
        text = skill_source_text(weapon, raw, store, warnings)
        fields = Wikitext.fields(text)
        args = Wikitext.full_values(text)
        full = args
        vars = {}
        if fields[:template]
          template = followed_page(store, "Template:#{fields[:template]}")
          if template
            fields = Wikitext.merge_template(fields, template)
            full = full.merge(Wikitext.full_values(template).reject { |_, v| v.match?(Wikitext::PLACEHOLDER) })
            vars = Evaluator.variables(template, args)
          else
            warnings << "#{weapon.granblue_id}: no stored Template:#{fields[:template]}"
          end
        end
        fields.merge(FULL_VALUES => full, ARGS => args, VARS => vars)
      end

      # Kept beside the parsed fields for resolving template-garbled names: every field's
      # whole value, the page's own parameters and the template's variables.
      FULL_VALUES = :full_values
      ARGS = :args
      VARS = :vars

      # Mk II pages transclude their base weapon ({{:Base}}); character pages name the weapon
      # page in their {{About|…|the weapon|<page>}} hatnote. A page with its own {{Weapon…}}
      # block is read as is, whatever hatnote it starts with (the old parser followed the
      # hatnote of every {{About}} page and lost those weapons when no "(Weapon)" page existed).
      def skill_source_text(weapon, raw, store, warnings)
        target = if (transclusion = raw[/\A\s*\{\{:([^|}\n]+)/, 1])
                   transclusion.strip
                 elsif raw =~ /\A\s*\{\{(?:About|Character|CharacterTabs)\b/i && !raw.match?(/^\{\{Weapon\b/)
                   raw[/\{\{About\|[^}]*?\|\s*the weapon\s*\|\s*([^}|]+)\}\}/i, 1]&.strip.presence ||
                     "#{weapon.name_en} (Weapon)"
                 end
        return raw unless target

        followed_page(store, target) || begin
          warnings << "#{weapon.granblue_id}: no stored page #{target.inspect}"
          ""
        end
      end

      # The page's stored expansion. A Mk II page that only transcludes its Mk I page
      # ({{:Concordia|…stats}}) renders the Mk I's skills, so the Mk I's expansion stands in
      # when the Mk II has none of its own.
      def expansion(store, page, raw)
        fetch(store, "expanded", page) ||
          ((base = raw[/\A\s*\{\{:([^|}\n]+)/, 1]) && fetch(store, "expanded", base.strip))
      end

      # Granblue::Parsers::Wiki#fetch in store mode: transclusions, then whole pages.
      def followed_page(store, key)
        (fetch(store, "transclusion", key) || fetch(store, "wiki_raw", key))&.body
      end

      def garbled?(slots)
        slots.any? { |slot| slot[:versions].any? { |entry| entry[:name_en].to_s.match?(GARBLED) } }
      end

      def untexted?(slots)
        slots.any? { |slot| slot[:versions].any? { |entry| entry[:description_en].blank? } }
      end

      # mode:
      #   :repair  series-template and garbled pages: the old expansion repair. Expanded skills
      #            matching a parsed tier give it their text and frame; the rest follow the
      #            last slot, where the repair appended them.
      #   :key     key-determined pages, which the repair never touched. Their base skill (the
      #            expansion's rows outside the key slots) takes the place of the garbled tier it
      #            renders, in page order, keeping that tier's slot, gate and icon, as the
      #            Draconic repair (data migration 20261015100001) did by hand.
      #   :text    other pages: nothing structural.
      # In :key and :text the expansion only gives a tier with no text of its own the text of
      # the expanded skill with its name (Skill#description_en is shared by name), and no frame.
      def build_versions(weapon, fields, raw, slots, expanded_rows, mode:)
        gid = weapon.granblue_id
        parsed = slots.flat_map do |slot|
          slot[:versions].map { |entry| entry.merge(position: slot[:position]) }
        end
        kept = parsed.reject { |entry| entry[:name_en].to_s.match?(GARBLED) }
        dropped = parsed - kept

        base_rows = Array(expanded_rows).reject { |row| row[:key_type] }
        names = kept.to_set { |entry| entry[:name_en] }
        by_name = base_rows.select { |row| names.include?(row[:name]) }.index_by { |row| row[:name] }
        added = mode == :text ? [] : placed_rows(base_rows - by_name.values, slots, dropped, mode)

        framed = mode == :repair ? framed_entries(kept, by_name) : Set.new
        versions = kept.map do |entry|
          row = by_name[entry[:name_en]]
          row = nil if mode != :repair && entry[:description_en].present?
          parsed_version(gid, fields, raw, entry, row, framed.include?(entry))
        end
        versions + added.map { |row| added_version(gid, fields, raw, row, dropped) }
      end

      # Expanded skills no parsed tier has, with the slot each lands in.
      def placed_rows(rows, slots, dropped, mode)
        next_position = (slots.map { |s| s[:position] }.max || -1) + 1
        free = mode == :key ? dropped.sort_by { |e| [e[:position], e[:ordinal]] } : []
        rows.map do |row|
          if (tier = free.shift)
            row.merge(position: tier[:position], ordinal: tier[:ordinal], replaces: tier)
          else
            row.merge(position: next_position).tap { next_position += 1 }
          end
        end
      end

      # The repair sets multiplier_frame on one version per matched name: the last one it
      # indexed (index_by over slots, then tiers).
      def framed_entries(kept, expanded_by_name)
        kept.select { |entry| expanded_by_name.key?(entry[:name_en]) }
            .group_by { |entry| entry[:name_en] }
            .to_set { |_, entries| entries.max_by { |e| [e[:position], e[:ordinal]] } }
      end

      def parsed_version(gid, fields, raw, entry, row, framed)
        text = TierText.from_wiki_hash(fields, entry[:position] + 1, entry[:suffix]) || {}
        # Skill#description_en: the tier's text, replaced by the expansion's when the repair matched
        skill_text = row ? row[:description] : entry[:description_en]
        modifier = entry[:modifier]
        Version.new(
          weapon_granblue_id: gid, position: entry[:position], ordinal: entry[:ordinal],
          skill_name_en: entry[:name_en], skill_name_jp: entry[:name_jp],
          description_en: text[:en] || row&.dig(:description), description_jp: text[:jp],
          unlock_level: entry[:unlock_level], min_uncap: entry[:min_uncap],
          transcendence_stage: entry[:transcendence_stage],
          skill_modifier: WeaponSkillVersion::VALID_MODIFIERS.include?(modifier) ? modifier : nil,
          skill_series: series(raw, entry[:position], entry[:name_en], skill_text,
                               fallback: Parser.series_for(entry[:description_en], entry[:name_en])),
          # the parse's size, else the size word of the skill's text (WeaponParser#persist_single_skill)
          skill_size: entry[:size] || Tiers.size_from_description(skill_text),
          multiplier_frame: framed ? row[:series] : nil,
          icon: entry[:icon], main_hand_only: entry[:main_hand_only], mc_only: entry[:mc_only]
        )
      end

      def added_version(gid, fields, raw, row, dropped)
        source = row[:replaces] || filled_tier(row[:name], dropped, fields)
        gate = source ? source.slice(:unlock_level, :min_uncap, :transcendence_stage) : {}
        Version.new(
          weapon_granblue_id: gid, position: row[:position], ordinal: row[:ordinal] || 0,
          skill_name_en: row[:name], skill_name_jp: nil,
          description_en: row[:description], description_jp: TierText.jp_for_name(fields, row[:name]),
          unlock_level: gate[:unlock_level], min_uncap: gate[:min_uncap] || 3,
          transcendence_stage: gate[:transcendence_stage] || 0,
          skill_modifier: nil,
          skill_series: series(raw, row[:position], row[:name], row[:description], fallback: row[:series]),
          skill_size: nil, multiplier_frame: row[:series], icon: row[:replaces]&.dig(:icon),
          main_hand_only: Expanded.main_hand_only_description?(row[:description]),
          mc_only: row[:description].to_s.match?(/\(mc only\)/i)
        )
      end

      # The dropped (template-garbled) tier an expanded skill fills in: its name with each
      # unresolved {{…}} read as a wildcard (page parameters and #if/#ifeq on them resolve
      # first). The lowest tier when a slot has several; nothing when slots disagree.
      def filled_tier(name, dropped, fields)
        matches = dropped.select { |entry| resolved_name(entry, fields) == name }
        if matches.empty?
          matches = dropped.select { |entry| name_pattern(entry[:name_en], fields)&.match?(name) }
        end
        return nil unless matches.map { |e| e[:position] }.uniq.size == 1

        matches.min_by { |e| e[:ordinal] }
      end

      INNERMOST = /\{\{[^{}]*\}\}/

      # The tier's whole name field evaluated with the page's parameters and the template's
      # variables (`{{ #switch: {{ #var: bahamutweapon }} |sabre=Vita Ignis … }}` → "Vita
      # Ignis"); nil while any other template call is left in it.
      def resolved_name(entry, fields)
        key = "s#{entry[:position] + 1}#{"_#{entry[:suffix]}" if entry[:suffix]}_name"
        value = fields.fetch(FULL_VALUES, {})[key] or return nil
        name = Evaluator.evaluate(value, fields.fetch(ARGS, {}), fields.fetch(VARS, {})).strip
        name.match?(GARBLED) || name.empty? ? nil : name
      end

      def name_pattern(garbled, fields)
        text = garbled.to_s.gsub(Wikitext::VAR, WILDCARD)
        text = Wikitext.conditionals(Wikitext.substitute_params(text, fields))
        text = text.gsub(INNERMOST, WILDCARD) while text.match?(INNERMOST)
        text = text.sub(/\{\{.*\z/m, WILDCARD) # a value cut off at its first line ("True {{")
        return nil if text.match?(GARBLED)

        literals = text.split(WILDCARD, -1)
        return nil if literals.join.strip.empty?

        Regexp.new("\\A#{literals.map { |l| Regexp.escape(l) }.join('.+')}\\z")
      end

      # The series the description extractor leaves on a version: the frame of the first
      # clause it parses ("ex" when that clause has none), else series_for(text, name). The
      # text is the page's full sN_desc for the tier with this name, else the skill text.
      def series(raw, position, name, skill_text, fallback: nil)
        return fallback if name.to_s.match?(GARBLED)

        text = Rows::Description.text(wiki_raw: raw, position: position, name: name, fallback: skill_text)
        return fallback if text.blank?

        clauses = Parser.parse(text, name: name)[:clauses]
        return clauses.filter_map { |c| c[:series] }.first || "ex" if clauses.any?

        Parser.series_for(text, name)
      end
    end
  end
end
