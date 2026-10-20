# frozen_string_literal: true

# The golden-snapshot shape for a built character skill graph (slots, versions,
# effects with resolved status names, and links), as stored under
# spec/fixtures/character_skills/golden/. Same shape as character_skill_golden_spec.rb.
module CharacterSkillGolden
  module_function

  def normalize(report, lookup)
    labels = {}
    report[:slots].each do |slot|
      slot[:versions].each { |v| labels[v[:key]] = "#{slot[:attrs][:kind]}#{slot[:attrs][:position]}:#{v[:attrs][:name_en]}" }
    end
    {
      'slots' => report[:slots].map { |slot| normalize_slot(slot, lookup) },
      'links' => report[:links].map { |link| [labels[link[:from_version_key]], link[:relation], labels[link[:to_version_key]]] }
    }
  end

  def normalize_slot(slot, lookup)
    { 'kind' => slot[:attrs][:kind], 'position' => slot[:attrs][:position],
      'versions' => slot[:versions].map { |version| normalize_version(version, lookup) } }
  end

  def normalize_version(version, lookup)
    attrs = version[:attrs]
    {
      'name_en' => attrs[:name_en], 'name_jp' => attrs[:name_jp],
      'description_en' => attrs[:description_en], 'description_jp' => attrs[:description_jp],
      'variant_role' => attrs[:variant_role], 'ordinal' => attrs[:ordinal], 'type_color' => attrs[:type_color],
      'cooldown' => attrs[:cooldown], 'initial_cooldown' => attrs[:initial_cooldown],
      'duration' => [attrs[:duration_value], attrs[:duration_unit]],
      'unlock_level' => attrs[:unlock_level], 'enhance_levels' => attrs[:enhance_levels],
      'min_uncap' => attrs[:min_uncap], 'transcendence_stage' => attrs[:transcendence_stage],
      'trigger' => [attrs[:trigger_type], attrs[:trigger_value]],
      'flags' => %i[cant_recast one_time_use auto_activate mimicable targets_all].select { |f| attrs[f] }.map(&:to_s),
      'effects' => version[:effects].map { |effect| normalize_effect(effect, lookup) }
    }
  end

  def normalize_effect(effect, lookup)
    {
      'type' => effect[:effect_type], 'target' => effect[:target],
      'status' => (lookup[:by_id][effect[:status_id]]&.name_en if effect[:status_id]),
      'amount' => effect[:amount], 'amount_max' => effect[:amount_max],
      'duration' => [effect[:duration_value], effect[:duration_unit]],
      'accuracy' => effect[:accuracy], 'stacking_frame' => effect[:stacking_frame],
      'damage_pct' => effect[:damage_pct]&.to_s, 'hit_count' => effect[:hit_count], 'damage_cap' => effect[:damage_cap]
    }
  end

  # Every game icon stem on the graph's ability versions.
  def ability_icons(report)
    report[:slots].select { |slot| slot[:attrs][:kind] == 'ability' }
                  .flat_map { |slot| slot[:versions].map { |v| v[:attrs][:game_icon] } }
                  .compact
  end
end
