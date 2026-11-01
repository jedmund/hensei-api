# frozen_string_literal: true

module Api
  module V1
    # A Guild War (a unite_and_fight Event) in the crew pages' shape: JST
    # start_date and end_date instead of starts_at and ends_at, and a status
    # of active, upcoming or finished.
    class GwEventBlueprint < ApiBlueprint
      fields :start_date, :end_date, :event_number

      field :element, &:element_value

      field :status do |event|
        if event.active?
          'active'
        elsif event.upcoming?
          'upcoming'
        else
          'finished'
        end
      end

      # Include crew's total score if participation data is provided
      field :crew_total_score, if: ->(_fn, event, options) { options[:participations]&.key?(event.id) } do |event, options|
        options[:participations][event.id]&.total_individual_honors
      end

      view :with_participation do
        field :participation, if: ->(_fn, _obj, options) { options[:participation].present? } do |_, options|
          CrewGwParticipationBlueprint.render_as_hash(options[:participation], view: :summary)
        end
      end
    end
  end
end
