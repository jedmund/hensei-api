# frozen_string_literal: true

class RemoveStandardCharacterSeries < ActiveRecord::Migration[8.0]
  def up
    # Find and delete the 'standard' series
    standard = CharacterSeries.find_by(slug: 'standard')

    if standard
      # Delete any memberships to 'standard' first
      membership_count = CharacterSeriesMembership.where(character_series: standard).delete_all
      puts "Deleted #{membership_count} memberships to 'standard' series"

      # Delete the series record
      standard.destroy!
      puts "Deleted 'standard' character series"
    else
      puts "'standard' character series not found, skipping"
    end

    # Update order values for remaining series (shift down by 1)
    CharacterSeries.where('order > 0').find_each do |cs|
      cs.update!(order: cs.order - 1)
    end
    puts "Updated order values for remaining series"
  end

  def down
    # Re-create the standard series and shift orders back up
    CharacterSeries.find_each do |cs|
      cs.update!(order: cs.order + 1)
    end

    CharacterSeries.create!(
      order: 0,
      slug: 'standard',
      name_en: 'Standard',
      name_jp: 'スタンダード'
    )
    puts "Re-created 'standard' character series"
  end
end
