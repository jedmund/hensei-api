FactoryBot.define do
  factory :job_accessory do
    association :job
    sequence(:name_en) { |n| "Job Accessory #{n}" }
    name_jp { "ジョブアクセサリー" }
    sequence(:granblue_id) { |n| "1#{n.to_s.rjust(8, '0')}" }

    trait :for_warrior do
      after(:build) do |accessory|
        accessory.job = Job.where(name_en: 'Warrior').first || FactoryBot.create(:job, name_en: 'Warrior')
      end
    end

    trait :for_sage do
      after(:build) do |accessory|
        accessory.job = Job.where(name_en: 'Sage').first || FactoryBot.create(:job, name_en: 'Sage')
      end
    end
  end
end