# frozen_string_literal: true

module Api
  module V1
    class CalculatorController < Api::V1::ApiController
      before_action :ensure_editor_role

      # POST /calculator/validate_panels — recompute every golden panel
      # reference and report per-party mismatches. The regression gate for
      # weapon-skill data edits.
      def validate_panels
        results = Granblue::PanelValidator.run(party: params[:party].presence)
        render json: {
          ok: results.all?(&:ok),
          panels: results.map do |r|
            { party: r.party, captured_on: r.captured_on, ok: r.ok, mismatches: r.mismatches }
          end
        }
      end
    end
  end
end
