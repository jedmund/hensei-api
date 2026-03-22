# frozen_string_literal: true

class Api::V1::CrewRosterBlueprint < Api::V1::ApiBlueprint
  fields :name, :element, :items, :created_at, :updated_at

  view :full do
    field :created_by do |roster|
      Api::V1::UserBlueprint.render_as_hash(roster.created_by, view: :minimal)
    end
  end
end
