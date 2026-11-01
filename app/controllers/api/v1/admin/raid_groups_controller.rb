# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only raid group list for the database editor, and its schema
      # (GBF-143).
      class RaidGroupsController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_editor_role

        admin_collection RaidGroup do
          search :name_en, :name_jp

          filter :section, type: :integer, facet: true
          filter :difficulty, type: :integer, facet: true
          filter :hl, type: :boolean
          filter :extra, type: :boolean
          filter :guidebooks, type: :boolean
          filter :unlimited, type: :boolean
          filter :support_summon, type: :boolean
          filter :created_at, type: :datetime
          filter :updated_at, type: :datetime

          sort :name_en, :name_jp, :section, :order, :difficulty, :updated_at, :created_at
          default_sort 'section', 'order'

          %i[name_en name_jp section order difficulty hl extra guidebooks unlimited support_summon content_mode
             created_at updated_at].each { |name| field name }
          field :raid_count, select: 'SELECT COUNT(*) FROM raids WHERE raids.group_id = raid_groups.id'
          # The party sizes of its raids, smallest first
          field :player_counts, select: 'ARRAY(SELECT DISTINCT raids.player_count FROM raids ' \
                                        'WHERE raids.group_id = raid_groups.id ORDER BY 1)'

          default_fields :name_en, :name_jp, :section, :order, :difficulty, :hl, :extra, :guidebooks, :unlimited,
                         :support_summon, :raid_count, :player_counts

          etag_sources :raids

          writable Api::V1::RaidGroupsController::PERMITTED
          enums section: RaidGroup::SECTIONS
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
