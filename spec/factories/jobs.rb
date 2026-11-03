FactoryBot.define do
  factory :job do
    sequence(:name_en) { |n| "Test Job #{n}" }
    name_jp { 'テストジョブ' }
    # Six digits, clear of the game's (which start 1-4)
    sequence(:granblue_id) { |n| "9#{(n % 100_000).to_s.rjust(5, '0')}" }
    row { '4' } # Class IV
    master_level { true }
    order { 1 }

    proficiency1 { 1 } # Sabre
    proficiency2 { 2 } # Dagger

    accessory { true }
    accessory_type { 1 }
    ultimate_mastery { true }
  end
end