FactoryBot.define do
  factory :collection_job_accessory do
    user
    job_accessory

    # Collection job accessories are simple - they either exist or don't
    # No uncap levels or other properties
  end
end
