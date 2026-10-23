# frozen_string_literal: true

FactoryBot.define do
  factory :character_skill_version do
    association :character_skill
    sequence(:name_en) { |n| "Skill #{n}" }
    name_jp { nil }
    description_en { nil }
    description_jp { nil }
    icon { nil }
    type_color { :buff }
    cooldown { nil }
    initial_cooldown { nil }
    duration_value { nil }
    duration_unit { nil }
    variant_role { :base }
    sequence(:ordinal) { |n| n }
    unlock_level { nil }
    enhance_levels { [] }
    min_uncap { nil }
    transcendence_stage { nil }
    trigger_type { :none }
    trigger_value { nil }
    cant_recast { false }
    one_time_use { false }
    auto_activate { false }
    mimicable { false }
    targets_all { false }
    game_action_id { nil }

    trait :enhanced do
      variant_role { :enhanced }
      unlock_level { 55 }
      enhance_levels { [55] }
    end

    trait :transform_alt do
      variant_role { :transform_alt }
      trigger_type { :on_cast_toggle }
    end

    trait :option do
      variant_role { :option }
      trigger_type { :menu_select }
    end

    trait :form_alt do
      variant_role { :form_alt }
      trigger_type { :form_state }
    end

    trait :auto do
      auto_activate { true }
    end
  end
end
