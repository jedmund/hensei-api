# frozen_string_literal: true

module Api
  module V1
    class PhantomPlayerBlueprint < ApiBlueprint
      fields :name, :granblue_id, :notes, :claim_confirmed, :retired, :retired_at, :joined_at

      field :claimed do |phantom|
        phantom.claimed_by_id.present?
      end

      view :with_claimed_by do
        field :claimed_by do |phantom|
          phantom.claimed_by ? UserBlueprint.render_as_hash(phantom.claimed_by, view: :minimal) : nil
        end
      end

      view :with_scores do
        include_view :with_claimed_by

        field :total_score do |phantom|
          phantom.gw_individual_scores.sum(:score)
        end

        field :score_count do |phantom|
          phantom.gw_individual_scores.count
        end
      end
    end
  end
end
