# frozen_string_literal: true

FactoryBot.define do
  factory :weapon_stat_modifier do
    sequence(:slug) { |n| "ax-modifier-#{n}" }
    sequence(:name_en) { |n| "AX Modifier #{n}" }
    category { 'ax' }
    polarity { 1 }

    trait :ax_atk do
      slug { 'ax_atk' }
      name_en { 'ATK' }
      category { 'ax' }
      stat { 'atk' }
      polarity { 1 }
      suffix { '%' }
      game_skill_id { 1589 }
    end

    trait :ax_hp do
      slug { 'ax_hp' }
      name_en { 'HP' }
      category { 'ax' }
      stat { 'hp' }
      polarity { 1 }
      suffix { '%' }
      game_skill_id { 1588 }
    end

    trait :befoulment do
      sequence(:slug) { |n| "befoul-modifier-#{n}" }
      sequence(:name_en) { |n| "Befoulment #{n}" }
      category { 'befoulment' }
      polarity { -1 }
    end

    trait :befoul_def_down do
      slug { 'befoul_def_down' }
      name_en { 'DEF Down' }
      category { 'befoulment' }
      stat { 'def' }
      polarity { -1 }
      suffix { '%' }
      game_skill_id { 2880 }
    end
  end
end
