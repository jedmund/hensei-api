# frozen_string_literal: true

FactoryBot.define do
  factory :wonder_category do
    sequence(:granblue_id) { |n| (100 + n).to_s }
    sequence(:name_en) { |n| "Category #{n}" }
    name_jp { 'カテゴリー' }
    category_type { 2 }
    sequence(:sort_order) { |n| n }
  end

  # A fixed Wonder by default.
  #   create(:wonder, :seal)    # leveled, Water, evolution caps 10/15/18/20
  #   create(:wonder, :yupei)   # leveled, Fire, max level 10
  #   create(:wonder, :symbolum)
  factory :wonder do
    wonder_category
    sequence(:granblue_id) { |n| (50_000 + n).to_s }
    sequence(:name_en) { |n| "Wonder #{n}" }
    name_jp { '大事なもの' }
    kind { 'fixed' }
    max_evolution { 0 }
    battle_relevant { true }
    sequence(:sort_order) { |n| n }

    trait :not_battle_relevant do
      battle_relevant { false }
    end

    trait :seal do
      kind { 'leveled' }
      max_level { 20 }
      max_evolution { 3 }
      element { 2 }
      hidden_in_unite_and_fight { true }
      after(:create) do |wonder|
        stats = %w[fire_resistance def double_attack_rate healing_cap debuff_resistance def triple_attack_rate
                   healing_cap debuff_resistance debuff_success_rate def healing_cap double_attack_rate
                   debuff_resistance triple_attack_rate debuff_resistance def healing_cap triple_attack_rate
                   fire_resistance]
        values = [5, 3, 3, 3, 3, 3, 3, 3, 3, 5, 3, 3, 3, 3, 2, 1, 3, 3, 2, 5]
        stats.each_with_index do |stat, index|
          wonder.level_bonuses.create!(level: index + 1, stat: stat, value: values[index])
        end
        { 0 => 10, 1 => 15, 2 => 18, 3 => 20 }.each do |evolution, max_level|
          wonder.evolution_caps.create!(evolution: evolution, max_level: max_level)
        end
        wonder.reload
      end
    end

    trait :yupei do
      kind { 'leveled' }
      max_level { 10 }
      element { 1 }
      after(:create) do |wonder|
        %w[fire_atk def skill_dmg ca_dmg fire_atk def dmg_amplify_vs_wind na_dmg_cap skill_dmg_cap
           ca_dmg_cap].each_with_index do |stat, index|
          wonder.level_bonuses.create!(level: index + 1, stat: stat, value: 5)
        end
        wonder.reload
      end
    end

    trait :symbolum do
      granblue_id { '9015' }
      kind { 'scaling' }
    end
  end

  factory :collection_wonder do
    user
    wonder
    active { true }
  end

  factory :party_wonder do
    party
    wonder
  end
end
