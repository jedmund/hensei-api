# frozen_string_literal: true

class MigrateCharacterAwakeningTypeToNewAwakeningType < ActiveRecord::Migration[7.0]
  def up
    GridCharacter.all.each do |character|
      slug = if character['awakening']['type'] == 0
               'character-balanced'
             elsif character['awakening']['type'] == 1
               'character-atk'
             elsif character['awakening']['type'] == 2
               'character-def'
             elsif character['awakening']['type'] == 3
               'character-multi'
             else
               'character-balanced'
             end

      new_awakening = Awakening.find_by(slug: slug)

      character.awakening_id = new_awakening.id
      character.awakening_level = character['awakening']['level']

      character.save!(validate: false)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
