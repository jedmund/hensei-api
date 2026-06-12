# frozen_string_literal: true

module Granblue
  module Parsers
    module CharacterSkills
      # Persists a parsed skill graph: destroys the character's existing skills and
      # recreates slots/versions/effects/links in one transaction (idempotent
      # re-persist). Unknown attribute keys are dropped per model column set.
      class Persister
        def initialize(character)
          @character = character
        end

        def persist(graph)
          ActiveRecord::Base.transaction do
            CharacterSkill.where(character_granblue_id: @character.granblue_id).destroy_all

            versions_by_key = {}
            graph[:slots].each do |slot_hash|
              slot = CharacterSkill.create!(permitted_attrs(CharacterSkill, slot_hash[:attrs]))
              slot_hash[:versions].each do |version_hash|
                version_attrs = permitted_attrs(CharacterSkillVersion, version_hash[:attrs]).merge(character_skill_id: slot.id)
                version = CharacterSkillVersion.create!(version_attrs)
                versions_by_key[version_hash[:key]] = version

                version_hash[:effects].each do |effect_hash|
                  effect_attrs = permitted_attrs(SkillEffect, effect_hash).merge(character_skill_version_id: version.id)
                  SkillEffect.create!(effect_attrs)
                end
              end
            end

            persist_links(graph[:links], versions_by_key)
          end
        end

        private

        def persist_links(links, versions_by_key)
          links.each do |link_hash|
            from_version = versions_by_key[link_hash[:from_version_key]]
            to_version = versions_by_key[link_hash[:to_version_key]]
            next if from_version.blank? || to_version.blank?

            CharacterSkillVersionLink.create!(
              from_version_id: from_version.id,
              to_version_id: to_version.id,
              relation: link_hash[:relation]
            )
          end
        end

        def permitted_attrs(model, attrs)
          attrs.slice(*model.column_names.map(&:to_sym))
        end
      end
    end
  end
end
