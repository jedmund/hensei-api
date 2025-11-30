FactoryBot.define do
  factory :job do
    sequence(:name_en) { |n| "Test Job #{n}" }
    name_jp { "テストジョブ" }
    sequence(:granblue_id) { |n| "3#{n.to_s.rjust(8, '0')}" }
    row { 4 } # Row IV
    master_level { 30 }
    order { 1 }

    proficiency1 { 1 } # Sabre
    proficiency2 { 2 } # Dagger

    accessory { true }
    accessory_type { 1 }
    ultimate_mastery { true }
  end
end