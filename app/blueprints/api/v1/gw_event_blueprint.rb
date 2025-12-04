# frozen_string_literal: true

module Api
  module V1
    class GwEventBlueprint < ApiBlueprint
      fields :name, :element, :start_date, :end_date, :event_number

      field :status do |event|
        if event.active?
          'active'
        elsif event.upcoming?
          'upcoming'
        else
          'finished'
        end
      end

      view :with_participation do
        field :participation, if: ->(_fn, _obj, options) { options[:participation].present? } do |_, options|
          CrewGwParticipationBlueprint.render_as_hash(options[:participation], view: :summary)
        end
      end
    end
  end
end
