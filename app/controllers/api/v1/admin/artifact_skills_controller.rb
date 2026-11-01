# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only artifact skill list for the database editor, and its
      # schema (GBF-143). Skills are edited through ArtifactSkillsController;
      # there's no create or destroy.
      class ArtifactSkillsController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_editor_role

        admin_collection ArtifactSkill do
          search :name_en, :name_jp, :game_name_en, :game_name_jp

          # Groups and polarities by name, as the rest of the API sends them
          filter :skill_group, type: :string, facet: true
          filter :polarity, type: :string, facet: true
          filter :score_category, type: :integer, facet: true
          filter :updated_at, type: :datetime

          sort :skill_group, :modifier, :name_en, :name_jp, :game_name_en, :game_name_jp, :polarity,
               :score_category, :growth, :updated_at, :created_at
          default_sort 'skill_group', 'modifier'

          %i[skill_group modifier name_en name_jp game_name_en game_name_jp polarity score_category
             base_values suffix_en suffix_jp created_at updated_at].each { |name| field name }
          # A decimal column would serialize as a string
          field :growth, value: ->(skill) { skill.growth&.to_f }

          default_fields :skill_group, :modifier, :name_en, :name_jp, :game_name_en, :game_name_jp,
                         :polarity, :base_values, :suffix_en, :suffix_jp

          writable Api::V1::ArtifactSkillsController::PERMITTED
          enums skill_group: ArtifactSkill.skill_groups, polarity: ArtifactSkill.polarities,
                score_category: ArtifactSkill::SCORE_CATEGORIES
        end

        def index
          render_admin_collection
        end

        def schema
          render_admin_schema
        end
      end
    end
  end
end
