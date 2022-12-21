# frozen_string_literal: true

module Api
  module V1
    class JobBlueprint < ApiBlueprint
      fields :id, :row, :ml, :order

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
    end
  end
end
