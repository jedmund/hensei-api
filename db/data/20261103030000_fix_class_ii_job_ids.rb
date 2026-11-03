# frozen_string_literal: true

# Class II jobs were stored with their Class I job's game id (Warrior had
# Fighter's 100001), so they showed Class I art and the extension's imports
# couldn't find them. The game numbers a class line by tier: Fighter 100001,
# Warrior 100101, Weapon Master 100201. This moves the ten Class II jobs to
# their own ids.
class FixClassIiJobIds < ActiveRecord::Migration[8.1]
  def up
    Job.where(row: '2').where("granblue_id ~ '^[0-9]{2}0001$'").find_each do |job|
      new_id = "#{job.granblue_id[0, 2]}0101"
      if Job.exists?(granblue_id: new_id)
        say "#{job.name_en}: #{new_id} is taken, left at #{job.granblue_id}"
        next
      end

      say "#{job.name_en}: #{job.granblue_id} -> #{new_id}"
      job.update_columns(granblue_id: new_id, updated_at: Time.current)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
