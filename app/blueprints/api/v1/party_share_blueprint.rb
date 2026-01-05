# frozen_string_literal: true

module Api
  module V1
    class PartyShareBlueprint < ApiBlueprint
      identifier :id

      fields :created_at

      field :shareable_type do |share|
        share.shareable_type.downcase
      end

      field :shareable_id do |share|
        share.shareable_id
      end

      view :with_shareable do
        fields :created_at

        field :shareable_type do |share|
          share.shareable_type.downcase
        end

        field :shareable do |share|
          case share.shareable_type
          when 'Crew'
            CrewBlueprint.render_as_hash(share.shareable, view: :minimal)
          end
        end

        field :shared_by do |share|
          UserBlueprint.render_as_hash(share.shared_by, view: :minimal)
        end
      end

      view :with_party do
        fields :created_at

        field :shareable_type do |share|
          share.shareable_type.downcase
        end

        field :party do |share|
          PartyBlueprint.render_as_hash(share.party, view: :preview)
        end

        field :shareable do |share|
          case share.shareable_type
          when 'Crew'
            CrewBlueprint.render_as_hash(share.shareable, view: :minimal)
          end
        end
      end
    end
  end
end
