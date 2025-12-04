# frozen_string_literal: true

module CrewAuthorizationConcern
  extend ActiveSupport::Concern

  # Checks whether the current user is a member of the crew
  def authorize_crew_member!
    render_unauthorized_response unless current_user&.crew == @crew
  end

  # Checks whether the current user is an officer (captain or vice captain) of the crew
  def authorize_crew_officer!
    render_unauthorized_response unless current_user&.crew == @crew && current_user.crew_officer?
  end

  # Checks whether the current user is the captain of the crew
  def authorize_crew_captain!
    render_unauthorized_response unless current_user&.crew == @crew && current_user.crew_captain?
  end
end
