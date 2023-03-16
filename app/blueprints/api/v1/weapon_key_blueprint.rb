# frozen_string_literal: true

module Api
  module V1
    class WeaponKeyBlueprint < ApiBlueprint
      field :name do |key|
        {
          en: key.name_en,
          ja: key.name_jp
        }
      end

      fields :granblue_id, :slug, :series, :slot, :group, :order
    end
  end
end
