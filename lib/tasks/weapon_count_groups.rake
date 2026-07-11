# frozen_string_literal: true

namespace :granblue do
  desc "Export named weapon-count groups from the DB for review/debugging"
  task export_weapon_count_groups: :environment do
    groups = WeaponCountGroup.includes(:weapons).order(:slug).map do |group|
      {
        "slug" => group.slug,
        "name_en" => group.name_en,
        "name_jp" => group.name_jp,
        "notes" => group.notes,
        "weapon_granblue_ids" => group.weapons.sort_by(&:granblue_id).map(&:granblue_id)
      }.compact
    end

    payload = {
      "_generated" => "Review snapshot only. The hensei DB is the source of truth for weapon-count groups.",
      "groups" => groups
    }
    output = "#{JSON.pretty_generate(payload)}\n"

    if ENV["OUTPUT"].present?
      File.write(ENV.fetch("OUTPUT"), output)
      puts "Exported #{groups.size} weapon-count group(s) to #{ENV.fetch('OUTPUT')}."
    else
      puts output
    end
  end
end
