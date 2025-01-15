# frozen_string_literal: true

class PopulateWeaponRecruits < ActiveRecord::Migration[7.0]
  def up
    # Get all character mappings and convert to hash properly
    results = execute(<<-SQL)
      SELECT id, granblue_id 
      FROM characters 
      WHERE granblue_id IS NOT NULL
    SQL

    character_mapping = {}
    results.each do |row|
      character_mapping[row['id']] = row['granblue_id']
    end

    # Update weapons table using the mapping
    character_mapping.each do |char_id, granblue_id|
      execute(<<-SQL)
        UPDATE weapons 
        SET recruits = #{connection.quote(granblue_id)} 
        WHERE recruits_id = #{connection.quote(char_id)}
      SQL
    end
  end

  def down
    execute("UPDATE weapons SET recruits = NULL")
  end
end
