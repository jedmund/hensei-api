# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ParseStringGameRaw' do
  let(:migration_class) do
    require Rails.root.join('db/data/20261020120000_parse_string_game_raw') unless defined?(ParseStringGameRaw)
    ParseStringGameRaw
  end

  def set_raw(record, column, sql_value)
    record.class.connection.execute(
      "UPDATE #{record.class.table_name} SET #{column} = #{sql_value} WHERE id = #{record.class.connection.quote(record.id)}"
    )
  end

  def typeof(record, column)
    record.class.where(id: record.id).pick(Arel.sql("jsonb_typeof(#{column})"))
  end

  it 'parses JSON strings into objects and clears JSON nulls' do
    character = create(:character)
    weapon = create(:weapon)
    summon = create(:summon)
    untouched = create(:character)
    set_raw(character, :game_raw_en, "to_jsonb('{\"id\":\"1\",\"ability\":{}}'::text)")
    set_raw(character, :game_raw_jp, "'null'::jsonb")
    set_raw(weapon, :game_raw_jp, "to_jsonb('{\"id\":\"2\"}'::text)")
    set_raw(summon, :game_raw_en, "to_jsonb('not json'::text)")
    set_raw(untouched, :game_raw_en, "'{\"id\":\"3\"}'::jsonb")

    migration_class.new.tap { |m| m.verbose = false }.up

    aggregate_failures do
      expect(character.reload.game_raw_en).to eq('id' => '1', 'ability' => {})
      expect(typeof(character, :game_raw_en)).to eq('object')
      expect(Character.where(id: character.id).pick(Arel.sql('game_raw_jp IS NULL'))).to be(true)
      expect(weapon.reload.game_raw_jp).to eq('id' => '2')
      expect(typeof(summon, :game_raw_en)).to eq('string')
      expect(untouched.reload.game_raw_en).to eq('id' => '3')
    end
  end
end
