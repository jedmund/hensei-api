# frozen_string_literal: true

class PopulateArtifacts < ActiveRecord::Migration[8.0]
  def up
    require 'csv'

    csv_path = Rails.root.join('lib', 'seeds', 'artifacts.csv')
    csv_text = File.read(csv_path)
    csv = CSV.parse(csv_text, headers: true, encoding: 'UTF-8')

    puts 'Creating artifact records...'
    csv.each do |row|
      artifact = Artifact.find_or_initialize_by(granblue_id: row['granblue_id'])
      artifact.assign_attributes(
        name_en: row['name_en'],
        name_jp: row['name_jp'],
        proficiency: row['proficiency'].presence,
        rarity: row['rarity'],
        release_date: row['release_date']
      )
      artifact.save!
      puts "  #{artifact.granblue_id}: #{artifact.name_en}"
    end

    puts "\nCreated #{Artifact.count} artifact records"
  end

  def down
    Artifact.delete_all
  end
end
