FactoryBot.define do
  factory :grid_character do
    association :party
    # Use the canonical (seeded) Character record.
    # Make sure your CSV canonical data (loaded via canonical.rb) includes a Character with the specified granblue_id.
    character { Character.find_by!(granblue_id: '3040087000') }
    position { 0 }
    uncap_level { 3 }
    transcendence_step { 0 }
    # Virtual attributes default to nil.
    new_rings { nil }
    new_awakening { nil }
    # JSON columns for ring data are set to default hashes.
    ring1 { { 'modifier' => nil, 'strength' => nil } }
    ring2 { { 'modifier' => nil, 'strength' => nil } }
    ring3 { { 'modifier' => nil, 'strength' => nil } }
    ring4 { { 'modifier' => nil, 'strength' => nil } }
    earring { { 'modifier' => nil, 'strength' => nil } }
  end
end
