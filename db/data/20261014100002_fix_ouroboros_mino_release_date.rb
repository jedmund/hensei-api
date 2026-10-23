# frozen_string_literal: true

# Ouroboros Mino was recorded as released on 2022-09-06, a year early. It came
# out on 2023-09-06. Only a row still holding the old date is changed.
class FixOuroborosMinoReleaseDate < ActiveRecord::Migration[8.1]
  def up
    JobAccessory.where(name_en: 'Ouroboros Mino', release_date: Date.new(2022, 9, 6))
                .update_all(release_date: Date.new(2023, 9, 6))
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
