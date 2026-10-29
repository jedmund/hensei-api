# frozen_string_literal: true

module PartyDifficulty
  module Rules
    # Presentation metadata only: the rule implementations remain the authority
    # for validation and scoring. Templates deliberately leave catalogue lists
    # empty so example IDs cannot accidentally become a saved condition.
    module EditorDefinitions
      TEMPLATES = {
        'weapon_series_match' => { slugs: [], min_count: 1 },
        'weapon_seasonal_match' => { seasons: [3], min_count: 1 },
        'weapon_tier_match' => { series_slugs: [], min_uncap_level: 5, min_count: 1 },
        'weapon_specific_match' => { weapon_ids: [], min_count: 1 },
        'weapon_awakening_at_least' => { min_level: 5, min_count: 1 },
        'weapon_transcendence_at_least' => { min_step: 4, min_count: 1 },
        'weapon_uncap_at_least' => { min_uncap_level: 5, min_count: 1, gacha_filter: 'any' },
        'weapon_promotion_includes' => { promotions: %w[Flash Legend], min_count: 1 },
        'weapon_ax_filled' => { min_filled: 1, min_count: 1 },
        'weapon_befoulment_filled' => { min_count: 1 },
        'weapon_release_within_days' => { days: 14, min_days_ago: 0, min_count: 1 },
        'weapon_bullet_match' => { bullet_ids: [], min_count: 1 },
        'character_seasonal' => { seasons: [], min_count: 1 },
        'character_series_match' => { slugs: [], min_count: 1, single_series_only: false },
        'character_perpetuity_ringed' => { min_count: 1 },
        'character_earring_at_least' => { min_strength: 17, min_count: 1 },
        'character_transcendence_at_least' => { min_step: 4, min_count: 1 },
        'character_release_within_days' => { days: 14, min_days_ago: 0, min_count: 1 },
        'summon_series_match' => { slugs: [], min_count: 1 },
        'summon_uncap_at_least' => { min_uncap_level: 3, min_count: 1, gacha_filter: 'any' },
        'summon_transcendence_at_least' => { min_step: 4, min_count: 1 },
        'summon_release_within_days' => { days: 14, min_days_ago: 0, min_count: 1 },
        'job_row' => { rows: %w[IV V Origin], requires_ultimate_mastery: false },
        'accessory_match' => { accessory_ids: [], accessory_types: [] },
        'mainhand_bullet_match' => { bullet_ids: [], min_count: 1, scale_by_count: true, max_count: 4 }
      }.freeze

      DESCRIPTIONS = {
        'weapon_series_match' => 'Matches weapons belonging to the supplied series',
        'weapon_seasonal_match' => 'Matches weapons that recruit characters from the supplied seasons',
        'weapon_tier_match' => 'Matches weapons satisfying every supplied tier filter',
        'weapon_specific_match' => 'Matches copies of the supplied weapons',
        'weapon_awakening_at_least' => 'Matches weapons with an awakening at or above the minimum level',
        'weapon_transcendence_at_least' => 'Matches weapons at or above the minimum transcendence step',
        'weapon_uncap_at_least' => 'Matches weapons at or above the minimum uncap level',
        'weapon_promotion_includes' => 'Matches weapons with any of the supplied promotions',
        'weapon_ax_filled' => 'Matches weapons with at least the specified number of filled AX slots',
        'weapon_befoulment_filled' => 'Matches weapons with a befoulment modifier',
        'weapon_release_within_days' => 'Matches weapons released within the supplied age range',
        'weapon_bullet_match' => 'Counts weapons carrying any of the supplied bullets',
        'character_seasonal' => 'Matches seasonal characters, optionally restricted to specific seasons',
        'character_series_match' => 'Matches characters belonging to the supplied series',
        'character_perpetuity_ringed' => 'Matches characters with a perpetuity ring',
        'character_earring_at_least' => 'Matches characters with an earring at or above the minimum strength',
        'character_transcendence_at_least' => 'Matches characters at or above the minimum transcendence step',
        'character_release_within_days' => 'Matches characters released within the supplied age range',
        'summon_series_match' => 'Matches owned summons belonging to the supplied series; friend summons are excluded',
        'summon_uncap_at_least' => 'Matches owned summons within the uncap range; friend summons are excluded',
        'summon_transcendence_at_least' => 'Matches owned summons at or above the minimum transcendence step; friend summons are excluded',
        'summon_release_within_days' => 'Matches owned summons within the supplied age range; friend summons are excluded',
        'job_row' => 'Matches the party job’s row, optionally requiring ultimate mastery',
        'accessory_match' => 'Matches the party accessory by ID or type',
        'mainhand_bullet_match' => 'Counts matching bullets on the mainhand weapon under the accessory component'
      }.freeze

      HELP = {
        min_count: 'Minimum number of matches needed to score (default 1).',
        scale_by_count: 'Optional boolean (default false): score every match instead of the first.',
        max_count: 'Optional denominator cap when scaling by count (default 1); does not cap the number of scored matches.',
        slugs: 'Supply series slugs, or use series_ids with catalogue UUIDs. At least one list must be nonempty.',
        series_ids: 'Optional series UUIDs; combined with the slug list.',
        series_slugs: 'Optional weapon series slugs. All supplied tier filters must match; supply a series or positive minimum level.',
        seasons: 'Seasons: 1 Valentine, 2 Formal, 3 Summer, 4 Halloween, 5 Holiday. ' \
                 'Weapon rules require a nonempty list; empty character seasons matches any seasonal character.',
        weapon_ids: 'Required nonempty list of weapon catalogue UUIDs.',
        bullet_ids: 'Required nonempty list of bullet catalogue UUIDs.',
        accessory_ids: 'Accessory UUIDs; supply these or accessory_types.',
        accessory_types: 'Accessory types: 1 shield, 2 manatura. Supply these or accessory_ids.',
        min_level: 'Required positive minimum awakening level.',
        awakening_id: 'Optional awakening UUID to restrict the awakening type.',
        min_step: 'Required positive minimum transcendence step.',
        min_uncap_level: 'Positive minimum uncap level (required for uncap rules).',
        max_uncap_level: 'Optional inclusive maximum uncap level for summon uncap and weapon tier rules.',
        min_transcendence_step: 'Optional positive minimum transcendence step.',
        max_transcendence_step: 'Optional inclusive maximum transcendence step.',
        min_awakening_level: 'Optional positive minimum awakening level.',
        max_awakening_level: 'Optional inclusive maximum awakening level.',
        gacha_filter: 'Optional: "gacha", "free", or "any" (default).',
        promotions: 'Required nonempty list of promotion names, such as Premium, Classic, Flash, or Legend.',
        min_filled: 'Minimum filled AX slots per weapon (default 1).',
        days: 'Required positive age limit in days; matches releases between days ago and min_days_ago, inclusively.',
        min_days_ago: 'Optional minimum release age in days (default 0).',
        single_series_only: 'Optional boolean: count characters only when they belong to a single series.',
        min_strength: 'Required positive minimum earring strength; the earring must also have a modifier.',
        rows: 'Required nonempty list of job row strings, such as "IV", "V", or "Origin".',
        requires_ultimate_mastery: 'Optional boolean: require a positive ultimate mastery level.',
        decay_per_year: 'Optional yearly reduction per match (e.g. 0.1 = 10%); default 0.',
        decay_floor: 'Optional minimum age multiplier (default 0.1).'
      }.freeze

      def self.all
        Rules.registered_types.map do |type|
          template = TEMPLATES.fetch(type)
          keys = template.keys
          keys += %i[scale_by_count max_count]
          keys += [:series_ids] if template.key?(:slugs) || template.key?(:series_slugs)
          keys += [:awakening_id] if type == 'weapon_awakening_at_least'
          keys += [:max_uncap_level] if type == 'summon_uncap_at_least'
          if type == 'weapon_tier_match'
            keys += %i[max_uncap_level min_transcendence_step max_transcendence_step
                       min_awakening_level max_awakening_level awakening_id gacha_filter]
          end
          keys += %i[decay_per_year decay_floor] if %w[weapon_series_match weapon_tier_match weapon_seasonal_match character_seasonal].include?(type)
          {
            rule_type: type, component: Rules.component_for(type),
            description: DESCRIPTIONS.fetch(type),
            params: template.deep_dup,
            parameters: keys.uniq.map { |key| { key: key.to_s, description: HELP.fetch(key) } }
          }
        end
      end
    end
  end
end
