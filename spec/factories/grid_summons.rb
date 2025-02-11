# frozen_string_literal: true

FactoryBot.define do
  factory :grid_summon do
    association :party
    # Use the canonical (seeded) Summon record.
    # Make sure your CSV canonical data (loaded via canonical.rb) includes a Summon with the specified granblue_id.
    summon { Summon.find_by!(granblue_id: '2040433000') }
    position { 1 }
    uncap_level { 3 }
    transcendence_step { 0 }
    main { false }
    friend { false }
    quick_summon { false }
  end
end
