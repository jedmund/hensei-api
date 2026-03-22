class SeedCrewRostersForExistingCrews < ActiveRecord::Migration[8.0]
  def up
    Crew.find_each do |crew|
      captain = crew.crew_memberships.find_by(role: :captain)&.user
      next unless captain

      CrewRoster.seed_for_crew!(crew, captain)
    end
  end

  def down
    CrewRoster.delete_all
  end
end
