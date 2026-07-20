# frozen_string_literal: true

##
# Seeds for WeaponStatModifier - AX skills and befoulments
#

puts 'Seeding weapon stat modifiers...'

ax_skills = [
  # Primary AX Skills
  { slug: 'ax_hp', ax_group: 'primary', name_en: 'HP', name_jp: 'HP', category: 'ax', stat: 'hp', polarity: 1, suffix: '%', base_min: 1,
base_max: 11, game_skill_id: 1588 },
  { slug: 'ax_atk', ax_group: 'primary', name_en: 'ATK', name_jp: '攻撃', category: 'ax', stat: 'atk', polarity: 1, suffix: '%', base_min: 1,
base_max: 3.5, game_skill_id: 1589 },
  { slug: 'ax_def', ax_group: 'primary', name_en: 'DEF', name_jp: '防御', category: 'ax', stat: 'def', polarity: 1, suffix: '%', base_min: 1,
base_max: 8, game_skill_id: 1590 },
  { slug: 'ax_ca_dmg', ax_group: 'primary', name_en: 'C.A. DMG', name_jp: '奥義ダメ', category: 'ax', stat: 'ca_dmg', polarity: 1, suffix: '%',
base_min: 2, base_max: 8.5, game_skill_id: 1591 },
  { slug: 'ax_multiattack', ax_group: 'primary', name_en: 'Multiattack Rate', name_jp: '連撃率', category: 'ax', stat: 'multiattack', polarity: 1,
suffix: '%', base_min: 1, base_max: 4, game_skill_id: 1592 },

  # Secondary AX Skills
  { slug: 'ax_debuff_res', ax_group: 'secondary', name_en: 'Debuff Resistance', name_jp: '弱体耐性', category: 'ax', stat: 'debuff_res', polarity: 1,
suffix: '%', base_min: 1, base_max: 3, game_skill_id: 1593 },
  { slug: 'ax_ele_atk', ax_group: 'secondary', name_en: 'Elemental ATK', name_jp: '全属性攻撃力', category: 'ax', stat: 'ele_atk', polarity: 1,
suffix: '%', base_min: 1, base_max: 5, game_skill_id: 1594 },
  { slug: 'ax_healing', ax_group: 'secondary', name_en: 'Healing', name_jp: '回復性能', category: 'ax', stat: 'healing', polarity: 1, suffix: '%',
base_min: 2, base_max: 5, game_skill_id: 1595 },
  { slug: 'ax_da', ax_group: 'secondary', name_en: 'Double Attack Rate', name_jp: 'DA確率', category: 'ax', stat: 'da', polarity: 1, suffix: '%',
base_min: 1, base_max: 2, game_skill_id: 1596 },
  { slug: 'ax_ta', ax_group: 'secondary', name_en: 'Triple Attack Rate', name_jp: 'TA確率', category: 'ax', stat: 'ta', polarity: 1, suffix: '%',
base_min: 1, base_max: 2, game_skill_id: 1597 },
  { slug: 'ax_ca_cap', ax_group: 'secondary', name_en: 'C.A. DMG Cap', name_jp: '奥義上限', category: 'ax', stat: 'ca_cap', polarity: 1, suffix: '%',
base_min: 1, base_max: 2, game_skill_id: 1599 },
  { slug: 'ax_stamina', ax_group: 'secondary', name_en: 'Stamina', name_jp: '渾身', category: 'ax', stat: 'stamina', polarity: 1, suffix: nil,
base_min: 1, base_max: 3, game_skill_id: 1600 },
  { slug: 'ax_enmity', ax_group: 'secondary', name_en: 'Enmity', name_jp: '背水', category: 'ax', stat: 'enmity', polarity: 1, suffix: nil,
base_min: 1, base_max: 3, game_skill_id: 1601 },
  { slug: 'ax_skill_cap', ax_group: 'secondary', name_en: 'Skill DMG Cap', name_jp: 'アビダメ上限', category: 'ax', stat: 'skill_cap', polarity: 1,
suffix: '%', base_min: 1, base_max: 2 },

  # Extended AX Skills (axType 2)
  { slug: 'ax_skill_supp', ax_group: 'extended', name_en: 'Supplemental Skill DMG', name_jp: 'アビ与ダメ上昇', category: 'ax', stat: 'skill_supp',
polarity: 1, suffix: nil, base_min: 1, base_max: 5, game_skill_id: 1719 },
  { slug: 'ax_ca_supp', ax_group: 'extended', name_en: 'Supplemental C.A. DMG', name_jp: '奥義与ダメ上昇', category: 'ax', stat: 'ca_supp', polarity: 1,
suffix: nil, base_min: 1, base_max: 5, game_skill_id: 1720 },
  { slug: 'ax_ele_dmg_red', ax_group: 'extended', name_en: 'Elemental DMG Reduction', name_jp: '属性ダメ軽減', category: 'ax', stat: 'ele_dmg_red',
polarity: 1, suffix: '%', base_min: 1, base_max: 5, game_skill_id: 1721 },
  { slug: 'ax_na_cap', ax_group: 'extended', name_en: 'Normal ATK DMG Cap', name_jp: '通常ダメ上限', category: 'ax', stat: 'na_cap', polarity: 1,
suffix: '%', base_min: 0.5, base_max: 1.5, game_skill_id: 1722 },

  # Utility AX Skills (axType 3)
  { slug: 'ax_exp', ax_group: 'utility', name_en: 'EXP Gain', name_jp: 'EXP UP', category: 'ax', stat: 'exp', polarity: 1, suffix: '%', base_min: 5,
base_max: 10, game_skill_id: 1837 },
  { slug: 'ax_rupie', ax_group: 'utility', name_en: 'Rupie Gain', name_jp: '獲得ルピ', category: 'ax', stat: 'rupie', polarity: 1, suffix: '%',
base_min: 10, base_max: 20, game_skill_id: 1838 }
]

befoulments = [
  # Befoulments - game_skill_ids from game data (2873-2881, 2876 doesn't exist)
  { slug: 'befoul_atk_down', name_en: 'ATK Down', name_jp: '攻撃力DOWN', category: 'befoulment', stat: 'atk', polarity: -1, suffix: '%', base_min: -12,
base_max: -6, game_skill_id: 2873 },
  { slug: 'befoul_ability_dmg_down', name_en: 'Ability DMG Down', name_jp: 'アビリティダメージDOWN', category: 'befoulment', stat: 'ability_dmg',
polarity: -1, suffix: '%', base_min: -50, base_max: -50, game_skill_id: 2874 },
  { slug: 'befoul_ca_dmg_down', name_en: 'CA DMG Down', name_jp: '奥義ダメージDOWN', category: 'befoulment', stat: 'ca_dmg', polarity: -1, suffix: '%',
base_min: -38, base_max: -26, game_skill_id: 2875 },
  { slug: 'befoul_da_ta_down', name_en: 'DA/TA Down', name_jp: '連撃率DOWN', category: 'befoulment', stat: 'da_ta', polarity: -1, suffix: '%',
base_min: -22, base_max: -19, game_skill_id: 2877 },
  { slug: 'befoul_debuff_down', name_en: 'Debuff Success Down', name_jp: '弱体成功率DOWN', category: 'befoulment', stat: 'debuff_success', polarity: -1,
suffix: '%', base_min: -16, base_max: -6, game_skill_id: 2878 },
  { slug: 'befoul_hp_down', name_en: 'Max HP Down', name_jp: '最大HP減少', category: 'befoulment', stat: 'hp', polarity: -1, suffix: '%', base_min: -50,
base_max: -26, game_skill_id: 2879 },
  { slug: 'befoul_def_down', name_en: 'DEF Down', name_jp: '防御力DOWN', category: 'befoulment', stat: 'def', polarity: -1, suffix: '%', base_min: -25,
base_max: -21, game_skill_id: 2880 },
  { slug: 'befoul_dot', name_en: 'Damage Over Time', name_jp: '毎ターンダメージ', category: 'befoulment', stat: 'dot', polarity: -1, suffix: '%',
base_min: 6, base_max: 16, game_skill_id: 2881 }
]

(ax_skills + befoulments).each do |attrs|
  modifier = WeaponStatModifier.find_or_initialize_by(slug: attrs[:slug])
  modifier.assign_attributes(attrs)
  modifier.save!
end

WeaponStatModifier::AX_SECONDARY_RANGES.each do |slug, (min, max)|
  WeaponStatModifier.find_by(slug: slug)&.update!(secondary_min: min, secondary_max: max)
end
WeaponStatModifier::AX_SECONDARY_POOLS.each do |slug, pools|
  WeaponStatModifier.find_by(slug: slug)&.update!(ax_secondaries: pools)
end

puts "Created/updated #{WeaponStatModifier.count} weapon stat modifiers"
