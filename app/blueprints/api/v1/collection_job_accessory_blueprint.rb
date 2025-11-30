module Api
  module V1
    class CollectionJobAccessoryBlueprint < ApiBlueprint
      identifier :id

      fields :created_at, :updated_at

      association :job_accessory, blueprint: JobAccessoryBlueprint
    end
  end
end