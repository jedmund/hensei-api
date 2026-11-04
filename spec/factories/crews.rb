FactoryBot.define do
  factory :crew do
    sequence(:name) { |n| "Crew #{n}" }
    sequence(:gamertag) { |n| n.to_s(36).upcase.rjust(4, '0') }
    sequence(:granblue_crew_id) { |n| (10_000_000 + n).to_s }
    description { 'A test crew.' }
  end
end
