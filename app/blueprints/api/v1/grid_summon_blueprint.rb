# frozen_string_literal: true

module Api
  module V1
    class GridSummonBlueprint < ApiBlueprint
      fields :main, :friend, :position, :quick_summon, :uncap_level, :transcendence_step, :orphaned

      field :collection_summon_id
      field :out_of_sync, if: ->(_field, gs, _options) { gs.collection_summon_id.present? } do |gs|
        gs.out_of_sync?
      end

      view :preview do
        association :summon, blueprint: SummonBlueprint, view: :preview
      end

      view :nested do
        association :summon, blueprint: SummonBlueprint, view: :full
        association :role, blueprint: RoleBlueprint,
                    if: ->(_fn, gs, _opt) { gs.role.present? }
        field :substitution_note, if: ->(_fn, gs, _opt) { gs.substitution_note.present? }
        association :substitutions, blueprint: SubstitutionBlueprint,
                    if: ->(_fn, gs, _opt) { !gs.is_substitute? && gs.substitutions.any? }
      end

      view :full do
        include_view :nested
        association :party, blueprint: PartyBlueprint, view: :collection_source
      end

      view :uncap do
        association :party, blueprint: PartyBlueprint
        fields :position, :uncap_level, :transcendence_step
      end

      view :destroyed do
        fields :main, :friend, :position, :created_at, :updated_at
      end
    end
  end
end
