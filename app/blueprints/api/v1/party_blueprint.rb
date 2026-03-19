# frozen_string_literal: true

module Api
  module V1
    class PartyBlueprint < ApiBlueprint
      # Base fields that are always needed
      fields :local_id, :description, :shortcode, :visibility,
             :name, :element, :extra, :charge_attack,
             :button_count, :turn_count, :chain_count, :summon_count, :clear_time,
             :full_auto, :auto_guard, :auto_summon, :solo, :video_url,
             :collection_source_user_id,
             :created_at, :updated_at

      fields :local_id, :description, :charge_attack,
             :button_count, :turn_count, :chain_count, :summon_count,
             :master_level, :ultimate_mastery

      # Party associations
      association :user,
                  blueprint: UserBlueprint,
                  view: :minimal

      association :collection_source_user,
                  blueprint: UserBlueprint,
                  view: :minimal,
                  if: ->(_field_name, party, _options) { party.collection_source_user_id.present? }

      association :job,
                  blueprint: JobBlueprint

      association :raid,
                  blueprint: RaidBlueprint,
                  view: :nested

      field :boost do |party|
        { mod: party.boost_mod, side: party.boost_side }
      end

      # Minimal view for embedding in grid item responses
      view :collection_source do
        field :collection_source_user_id
        association :collection_source_user,
                    blueprint: UserBlueprint,
                    view: :minimal,
                    if: ->(_field_name, party, _options) { party.collection_source_user_id.present? }
      end

      # Slim view for party list cards — only fields GridRep actually renders
      view :list do
        excludes :local_id, :description, :visibility, :element, :extra,
                 :button_count, :turn_count, :chain_count, :summon_count, :clear_time,
                 :auto_guard, :auto_summon, :solo, :video_url,
                 :collection_source_user_id,
                 :created_at, :updated_at,
                 :master_level, :ultimate_mastery,
                 :user, :collection_source_user,
                 :job, :raid, :boost

        association :job, blueprint: JobBlueprint, view: :list
        association :raid, blueprint: RaidBlueprint, view: :list

        association :characters, blueprint: GridCharacterBlueprint, view: :list
        association :weapons, blueprint: GridWeaponBlueprint, view: :list
        association :summons, blueprint: GridSummonBlueprint, view: :list
      end

      # Summary view for embedding in remix/source lists — minimal party metadata
      view :summary do
        excludes :local_id, :description, :visibility, :element, :extra,
                 :button_count, :turn_count, :chain_count, :summon_count, :clear_time,
                 :auto_guard, :auto_summon, :solo, :video_url,
                 :collection_source_user_id,
                 :created_at, :updated_at,
                 :master_level, :ultimate_mastery,
                 :collection_source_user,
                 :job, :raid, :boost

        association :user, blueprint: UserBlueprint, view: :inline

        include_view :preview_metadata
      end

      # For collection views
      view :preview do
        include_view :preview_objects # Characters, Weapons, Summons
        include_view :preview_metadata # Object counts
        include_view :party_metadata # favorited, has_orphaned_items
      end

      # For object views
      view :full do
        # Primary object associations
        include_view :nested_objects # Characters, Weapons, Summons
        include_view :remix_metadata # Remixes, Source party
        include_view :job_metadata # Accessory, Skills, Guidebooks
        include_view :party_metadata # favorited, has_orphaned_items

        # Shares (only visible to owner)
        field :shares, if: ->(_field_name, party, options) {
          options[:current_user] && party.user_id == options[:current_user].id
        } do |party|
          party.party_shares.map do |share|
            {
              id: share.id,
              shareable_type: share.shareable_type.downcase,
              shareable_id: share.shareable_id,
              shareable_name: share.shareable.try(:name),
              created_at: share.created_at
            }
          end
        end

        # Viewing user's collection items matching this party's grid items
        field :viewer_collection, if: ->(_field_name, _party, options) {
          options[:viewer_collection].present?
        } do |_party, options|
          vc = options[:viewer_collection]
          {
            characters: CollectionCharacterBlueprint.render_as_hash(vc[:characters]),
            weapons: CollectionWeaponBlueprint.render_as_hash(vc[:weapons]),
            summons: CollectionSummonBlueprint.render_as_hash(vc[:summons])
          }
        end

        # Collection source user's items matching this party's grid items
        field :source_collection, if: ->(_field_name, _party, options) {
          options[:source_collection].present?
        } do |_party, options|
          sc = options[:source_collection]
          {
            characters: CollectionCharacterBlueprint.render_as_hash(sc[:characters]),
            weapons: CollectionWeaponBlueprint.render_as_hash(sc[:weapons]),
            summons: CollectionSummonBlueprint.render_as_hash(sc[:summons])
          }
        end
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

      # Computed metadata — only included in views that need it
      view :party_metadata do
        field :favorited do |party, options|
          if options[:favorite_party_ids]
            options[:favorite_party_ids].include?(party.id)
          else
            party.favorited?(options[:current_user])
          end
        end

        field :has_orphaned_items do |party|
          party.has_orphaned_items?
        end
      end

      view :source_party do
        association :source_party,
                    blueprint: PartyBlueprint,
                    view: :summary,
                    if: ->(_field_name, party, _options) { party.source_party_id.present? }
      end

      view :remix_metadata do
        include_view :source_party

        association :remixes,
                    blueprint: PartyBlueprint,
                    view: :summary
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

      # Remixed view
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
