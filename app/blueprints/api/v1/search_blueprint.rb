# frozen_string_literal: true

module Api
  module V1
    class SearchBlueprint < Blueprinter::Base
      identifier :searchable_id
      fields :searchable_type, :granblue_id, :name_en, :name_jp, :element
    end
  end
end
