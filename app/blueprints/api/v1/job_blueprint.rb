# frozen_string_literal: true

module Api
  module V1
    class JobBlueprint < ApiBlueprint
      field :name do |job|
        {
          en: job.name_en,
          ja: job.name_jp
        }
      end

      field :proficiency do |job|
        [
          job.proficiency1,
          job.proficiency2
        ]
      end

<<<<<<< HEAD
      fields :granblue_id, :row, :ml, :order
=======
      fields :granblue_id, :row, :order,
             :master_level, :ultimate_mastery,
             :accessory, :accessory_type
>>>>>>> main
    end
  end
end
