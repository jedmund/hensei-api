# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only raid list for the database editor, and its schema: what the
      # editor may filter, sort, show and write (GBF-143). The team builder's
      # raid picker stays at /raids.
      class RaidsController < Api::V1::ApiController
        include AdminCollection

        GROUP = 'SELECT %<column>s FROM raid_groups WHERE raid_groups.id = raids.group_id'

        before_action :ensure_editor_role

        admin_collection Raid do
          search :name_en, :name_jp, :slug

          filter :element, type: :integer, facet: true
          filter :group, type: :uuid, column: :group_id, facet: true
          filter :player_count, type: :integer, facet: true
          filter :level, type: :integer
          filter :released_at, type: :date
          filter :created_at, type: :datetime
          filter :updated_at, type: :datetime

          flag :hl, "EXISTS (#{format(GROUP, column: 1)} AND raid_groups.hl)"
          # A raid's own extra wins over its group's (Raid#effective_extra)
          flag :extra, "COALESCE(raids.extra, (#{format(GROUP, column: 'raid_groups.extra')}), false)"

          sort :name_en, :name_jp, :slug, :level, :element, :player_count, :released_at, :updated_at, :created_at
          sort :group_section, sql: format(GROUP, column: 'raid_groups.section')
          sort :group_order, sql: format(GROUP, column: 'raid_groups.order')
          # The raid picker's order: section, then group, then element and level
          default_sort 'group_section', 'group_order', 'element', 'level'

          %i[slug name_en name_jp level element player_count extra enemy_id summon_id quest_id
             released_at group_id created_at updated_at].each { |name| field name }
          field :group, includes: :group, value: lambda { |raid|
            raid.group&.slice(:id, :name_en, :name_jp, :section, :order)
          }

          default_fields :slug, :name_en, :name_jp, :level, :element, :player_count, :group, :updated_at

          etag_sources RaidGroup

          writable Api::V1::RaidsController::PERMITTED
          enums element: GranblueEnums::ELEMENTS, player_count: Raid::PLAYER_COUNTS
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
