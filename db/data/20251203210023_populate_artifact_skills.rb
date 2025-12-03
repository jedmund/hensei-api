# frozen_string_literal: true

class PopulateArtifactSkills < ActiveRecord::Migration[8.0]
  def up
    json_path = Rails.root.join('lib', 'seeds', 'artifact_skills.json')
    json_text = File.read(json_path)
    skills = JSON.parse(json_text)

    puts 'Creating artifact skill records...'
    skills.each do |skill_data|
      skill = ArtifactSkill.find_or_initialize_by(
        skill_group: skill_data['skill_group'],
        modifier: skill_data['modifier']
      )
      skill.assign_attributes(
        name_en: skill_data['name_en'],
        name_jp: skill_data['name_jp'],
        base_values: skill_data['base_values'],
        growth: skill_data['growth'],
        suffix_en: skill_data['suffix_en'] || '',
        suffix_jp: skill_data['suffix_jp'] || '',
        polarity: skill_data['polarity']
      )
      skill.save!
      puts "  Group #{skill_data['skill_group']}, Mod #{skill_data['modifier']}: #{skill.name_en}"
    end

    # Clear cache after seeding
    ArtifactSkill.clear_cache!

    puts "\nCreated #{ArtifactSkill.count} artifact skill records"
  end

  def down
    ArtifactSkill.delete_all
  end
end
