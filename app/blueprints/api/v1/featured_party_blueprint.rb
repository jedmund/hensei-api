# frozen_string_literal: true

module Api
  module V1
    # Pass PartyStickerSummary.batch_options so the parties' labels render
    # without a query per pick.
    class FeaturedPartyBlueprint < ApiBlueprint
      fields :event_id, :position

      field :note do |featured|
        { en: featured.note_en, ja: featured.note_jp }
      end

      association :party, blueprint: PartyBlueprint, view: :list
    end
  end
end
