# frozen_string_literal: true

namespace :granblue do
  desc "Repair incomplete weapons (series-template, no skill descriptions) by expanding the template and importing the rendered skills. LIMIT=n to cap."
  task refetch_expanded_weapons: :environment do
    stats = Granblue::Extractors::ExpandedWeaponSkillImporter.run(limit: ENV["LIMIT"]&.to_i)
    puts "Refetched expanded weapons:"
    stats.sort_by { |k, _| k.to_s }.each { |k, n| puts "  #{k}: #{n}" }
  end
end
