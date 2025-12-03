# frozen_string_literal: true

FactoryBot.define do
  factory :artifact_skill do
    skill_group { :group_i }
    # Use high sequence numbers to avoid conflicts with seeded data (modifiers 1-29 used)
    sequence(:modifier) { |n| 1000 + n }
    sequence(:name_en) { |n| "Test Skill #{n}" }
    name_jp { 'テストスキル' }
    base_values { [1320, 1440, 1560, 1680, 1800] }
    growth { 300.0 }
    suffix_en { '' }
    suffix_jp { '' }
    polarity { :positive }

    trait :group_i do
      skill_group { :group_i }
    end

    trait :group_ii do
      skill_group { :group_ii }
    end

    trait :group_iii do
      skill_group { :group_iii }
    end

    trait :atk do
      modifier { 1 }
      name_en { 'ATK' }
      name_jp { '攻撃力' }
      base_values { [1320, 1440, 1560, 1680, 1800] }
      growth { 300.0 }
    end

    trait :hp do
      modifier { 2 }
      name_en { 'HP' }
      name_jp { 'HP' }
      base_values { [660, 720, 780, 840, 900] }
      growth { 150.0 }
    end

    trait :ca_dmg do
      modifier { 3 }
      name_en { 'C.A. DMG' }
      name_jp { '奥義ダメ' }
      base_values { [13.2, 14.4, 15.6, 16.8, 18.0] }
      growth { 3.0 }
      suffix_en { '%' }
      suffix_jp { '%' }
    end

    trait :negative do
      polarity { :negative }
      growth { -6.0 }
    end

    trait :no_growth do
      growth { nil }
    end
  end
end
