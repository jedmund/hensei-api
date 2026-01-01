# frozen_string_literal: true

FactoryBot.define do
  factory :grid_weapon do
    # Associations: assumes that factories for :party and :weapon are defined.
    association :party
    association :weapon

    # Default attributes
    position { 0 }
    uncap_level { 3 }
    transcendence_step { 0 }
    mainhand { false }

    # AX skills (FK to weapon_stat_modifiers)
    ax_modifier1 { nil }
    ax_strength1 { nil }
    ax_modifier2 { nil }
    ax_strength2 { nil }

    # Befoulment (FK to weapon_stat_modifiers)
    befoulment_modifier { nil }
    befoulment_strength { nil }
    exorcism_level { 0 }

    # Optional associations for weapon keys and awakening are left as nil by default.

    # Trait for AX weapon with skills
    trait :with_ax do
      ax_strength1 { 3.5 }
      ax_strength2 { 10.0 }
      after(:build) do |grid_weapon|
        grid_weapon.ax_modifier1 = WeaponStatModifier.find_by(slug: 'ax_atk') ||
                                   FactoryBot.create(:weapon_stat_modifier, :ax_atk)
        grid_weapon.ax_modifier2 = WeaponStatModifier.find_by(slug: 'ax_hp') ||
                                   FactoryBot.create(:weapon_stat_modifier, :ax_hp)
      end
    end

    # Trait for Odiant weapon with befoulment
    trait :with_befoulment do
      befoulment_strength { 23.0 }
      exorcism_level { 2 }
      after(:build) do |grid_weapon|
        grid_weapon.befoulment_modifier = WeaponStatModifier.find_by(slug: 'befoul_def_down') ||
                                          FactoryBot.create(:weapon_stat_modifier, :befoul_def_down)
      end
    end
  end
end
