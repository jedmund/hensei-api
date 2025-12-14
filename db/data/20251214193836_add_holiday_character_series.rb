# frozen_string_literal: true

class AddHolidayCharacterSeries < ActiveRecord::Migration[8.0]
  def up
    CharacterSeries.find_or_create_by!(slug: 'holiday') do |cs|
      cs.order = 15
      cs.name_en = 'Holiday'
      cs.name_jp = 'クリスマス'
    end
    puts 'Created holiday character series'
  end

  def down
    CharacterSeries.find_by(slug: 'holiday')&.destroy
  end
end
