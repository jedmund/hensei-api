# frozen_string_literal: true

##
# Records a crew's Guild War scores from the game's member list. Each row is
# matched to an active member by their granblue id, else to a phantom
# player; ids that match neither get a new phantom. A row's score for the
# round is created or overwritten.
#
# @example
#   import = GwScoreImport.new(crew)
#   import.preview(%w[123 456]) # => { existing_phantom_ids: [...], new_phantom_ids: [...] }
#   result = import.import(participation, members, round: 'preliminaries', cumulative: false, recorded_by: user)
#   result.errors # => [{ index:, granblue_id:, errors: [...] }] for rows that didn't save
class GwScoreImport
  Result = Data.define(:imported, :phantoms_created, :errors)

  # @param crew [Crew]
  def initialize(crew)
    @crew = crew
  end

  # @param participation [CrewGwParticipation] the crew's entry in the event
  # @param members [Array<#[]>] rows of { granblue_id:, name:, score: }
  # @param round [String, Integer] a GwCrewScore round
  # @param cumulative [Boolean] whether the scores are totals so far
  # @param recorded_by [User]
  # @return [Result]
  def import(participation, members, round:, cumulative:, recorded_by:)
    membership_map = membership_ids
    phantom_map = phantom_ids
    imported = 0
    phantoms_created = 0
    errors = []

    members.each_with_index do |member_data, index|
      gbf_id = member_data[:granblue_id].to_s
      membership_id = membership_map[gbf_id]
      phantom_id = phantom_map[gbf_id]

      # Create phantom if no match found
      if membership_id.nil? && phantom_id.nil?
        phantom = find_or_create_phantom(gbf_id, member_data[:name])
        phantom_id = phantom_map[gbf_id] = phantom.id
        phantoms_created += 1 if phantom.previously_new_record?
      end

      score = participation.gw_individual_scores.find_or_initialize_by(
        crew_membership_id: membership_id, phantom_player_id: phantom_id, round: round
      )
      score.assign_attributes(score: member_data[:score], is_cumulative: cumulative, recorded_by: recorded_by)

      if score.save
        imported += 1
      else
        errors << { index: index, granblue_id: gbf_id, errors: score.errors.full_messages }
      end
    end

    Result.new(imported: imported, phantoms_created: phantoms_created, errors: errors)
  end

  # Splits granblue ids that aren't active members into those that already
  # have a phantom and those an import would create one for.
  # @param granblue_ids [Array<String, Integer>]
  # @return [Hash]
  def preview(granblue_ids)
    membership_map = membership_ids
    phantom_map = phantom_ids
    candidates = granblue_ids.map(&:to_s).reject { |id| membership_map[id] }
    existing, new_ids = candidates.partition { |id| phantom_map[id] }

    { existing_phantom_ids: existing, new_phantom_ids: new_ids }
  end

  private

  # granblue id => membership id. User.granblue_id is an integer in the
  # database; the game sends strings.
  def membership_ids
    @crew.active_memberships.includes(:user).each_with_object({}) do |membership, map|
      gbf_id = membership.user.granblue_id
      map[gbf_id.to_s] = membership.id if gbf_id.present?
    end
  end

  # granblue id => phantom id, for active phantoms that have one
  def phantom_ids
    @crew.phantom_players.not_deleted.active.where.not(granblue_id: [nil, '']).to_h do |phantom|
      [phantom.granblue_id, phantom.id]
    end
  end

  def find_or_create_phantom(gbf_id, name)
    @crew.phantom_players.find_or_create_by!(granblue_id: gbf_id) do |phantom|
      phantom.name = name
    end
  end
end
