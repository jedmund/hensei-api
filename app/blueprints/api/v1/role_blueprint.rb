# frozen_string_literal: true

module Api
  module V1
    class RoleBlueprint < ApiBlueprint
      fields :name_en, :name_jp, :slot_type, :sort_order
    end
  end
end
