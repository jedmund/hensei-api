# frozen_string_literal: true

class Api::V1::CrewRostersController < Api::V1::ApiController
  include CrewAuthorizationConcern

  before_action :restrict_access
  before_action :set_crew
  before_action :set_roster, only: %i[show update destroy]
  before_action :authorize_crew_officer!, only: %i[update destroy]

  def index
    rosters = @crew.crew_rosters.order(:element)
    render json: Api::V1::CrewRosterBlueprint.render(rosters, root: :crew_rosters)
  end

  def show
    result = { roster: Api::V1::CrewRosterBlueprint.render_as_hash(@roster, view: :full), items: [], members: [] }

    # If the roster has items, also fetch ownership data
    if @roster.items.present?
      ownership = CrewRosterOwnership.new(@roster, crew: @crew, viewer: current_user)
      result[:items] = ownership.items
      result[:members] = ownership.members
    end

    render json: result
  end

  def update
    @roster.update!(roster_params)
    render json: Api::V1::CrewRosterBlueprint.render(@roster, root: :crew_roster, view: :full)
  end

  def destroy
    @roster.destroy!
    head :no_content
  end

  private

  def set_crew
    @crew = current_user.crew
    render_not_found_response('crew') unless @crew
  end

  def set_roster
    @roster = @crew.crew_rosters.find(params.expect(:id))
  end

  def roster_params
    params.permit(:name, items: %i[id type])
  end
end
