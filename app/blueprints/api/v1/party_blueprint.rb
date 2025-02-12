# frozen_string_literal: true

module Api
  module V1
    class PartyBlueprint < ApiBlueprint
      # Base fields that are always needed
      fields :local_id, :description, :shortcode, :visibility,
             :name, :element, :extra, :charge_attack,
             :button_count, :turn_count, :chain_count, :clear_time,
             :full_auto, :auto_guard, :auto_summon,
             :created_at, :updated_at

      fields :local_id, :description, :charge_attack,
             :button_count, :turn_count, :chain_count,
             :master_level, :ultimate_mastery

      # Party associations
      association :user,
                  blueprint: UserBlueprint,
                  view: :minimal

      association :job,
                  blueprint: JobBlueprint

      association :raid,
                  blueprint: RaidBlueprint,
                  view: :nested

      # Metadata associations
      field :favorited do |party, options|
        party.is_favorited(options[:current_user])
      end

      # For collection views
      view :preview do
        include_view :preview_objects # Characters, Weapons, Summons
        include_view :preview_metadata # Object counts
      end

      # For object views
      view :full do
        # Primary object associations
        include_view :nested_objects # Characters, Weapons, Summons
        include_view :remix_metadata # Remixes, Source party
        include_view :job_metadata # Accessory, Skills, Guidebooks
      end

      # Primary object associations
      view :preview_objects do
        association :characters,
                    blueprint: GridCharacterBlueprint,
                    view: :preview

        association :weapons,
                    blueprint: GridWeaponBlueprint,
                    view: :preview

        association :summons,
                    blueprint: GridSummonBlueprint,
                    view: :preview
      end

      view :nested_objects do
        association :characters,
                    blueprint: GridCharacterBlueprint,
                    view: :nested

        association :weapons,
                    blueprint: GridWeaponBlueprint,
                    view: :nested

        association :summons,
                    blueprint: GridSummonBlueprint,
                    view: :nested
      end

      # Metadata views
      view :preview_metadata do
        field :counts do |party|
          {
            weapons: party.weapons_count,
            characters: party.characters_count,
            summons: party.summons_count
          }
        end
      end

      view :source_party do
        association :source_party,
                    blueprint: PartyBlueprint,
                    view: :preview,
                    if: ->(_field_name, party, _options) { party.source_party_id.present? }
      end

      view :remix_metadata do
        include_view :source_party

        # Re-added remixes association
        association :remixes,
                    blueprint: PartyBlueprint,
                    view: :preview
      end

      # Job-related views
      view :job_metadata do
        field :job_skills, cache: true do |party|
          {
            '0' => party.skill0 ? JobSkillBlueprint.render_as_hash(party.skill0) : nil,
            '1' => party.skill1 ? JobSkillBlueprint.render_as_hash(party.skill1) : nil,
            '2' => party.skill2 ? JobSkillBlueprint.render_as_hash(party.skill2) : nil,
            '3' => party.skill3 ? JobSkillBlueprint.render_as_hash(party.skill3) : nil
          }
        end

        field :guidebooks, cache: true do |party|
          {
            '1' => party.guidebook1 ? GuidebookBlueprint.render_as_hash(party.guidebook1) : nil,
            '2' => party.guidebook2 ? GuidebookBlueprint.render_as_hash(party.guidebook2) : nil,
            '3' => party.guidebook3 ? GuidebookBlueprint.render_as_hash(party.guidebook3) : nil
          }
        end

        association :accessory,
                    blueprint: JobAccessoryBlueprint,
                    if: ->(_field_name, party, _options) { party.accessory_id.present? }
      end

      # Created view
      view :created do
        include_view :full
        fields :edit_key
      end

      view :remixed do
        include_view :created
        include_view :source_party
      end

      # Destroyed view
      view :destroyed do
        fields :name, :description, :created_at, :updated_at
      end
    end
  end
end
