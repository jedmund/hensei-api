# frozen_string_literal: true

require 'rails_helper'

# The in-game panel references (data/panel_references/*.json) validated in CI. Each
# golden party is a self-contained fixture (spec/fixtures/goldens/<shortcode>.json): its
# party rows plus the catalogue rows the calculator reads for it. Each example empties
# those tables, loads one fixture, and checks one reference with PanelValidator.
# Refresh a fixture with `bin/rails granblue:export_golden_fixture shortcode=XXXXXX`.
RSpec.describe 'Golden panel references' do
  fixture_codes = Granblue::GoldenFixture.shortcodes
  references = fixture_codes.to_h { |code| [code, Granblue::GoldenFixture.references_for(code)] }

  it 'has a fixture for every golden party' do
    expect(fixture_codes).not_to be_empty
    references.each { |code, refs| expect(refs).not_to be_empty, "#{code} has no panel reference" }
  end

  references.each do |code, refs|
    refs.each do |name, ref|
      it "#{name} matches the in-game panel" do
        party = Granblue::GoldenFixture.load(code, mode: :replace)
        result = Granblue::PanelValidator.new(ref, party: party).validate

        expect(result.mismatches).to eq([])
        expect(result.ok).to be(true)
      end
    end
  end

  describe 'fixture files' do
    def keys_in(value)
      case value
      when Hash then value.keys + value.values.flat_map { |v| keys_in(v) }
      when Array then value.flat_map { |v| keys_in(v) }
      else []
      end
    end

    fixture_codes.each do |code|
      it "#{code} carries no user data or free text" do
        fixture = Granblue::GoldenFixture.read(code)

        expect(keys_in(fixture).uniq & Granblue::GoldenFixture::PRIVATE_KEYS).to eq([])
        expect(fixture['tables'].keys).not_to include('users', 'collection_weapons', 'collection_summons',
                                                     'collection_characters', 'favorites')
        expect(fixture['tables']['parties'].pluck('name')).to eq([code])
      end

      it "#{code} re-exports unchanged from a database loaded with it" do
        fixture = Granblue::GoldenFixture.read(code)
        Granblue::GoldenFixture.load(fixture, mode: :replace)
        again = Granblue::GoldenFixture.export(code)

        again["tables"].each { |t, rows| expect(rows).to eq(fixture["tables"][t]), t }
        expect(again.except("catalogue_tag")).to eq(fixture.except("catalogue_tag"))
      end
    end
  end

  describe 'loading party rows into an existing catalogue' do
    let(:code) { fixture_codes.first }
    let(:fixture) { Granblue::GoldenFixture.read(code) }

    it 'replaces the party and keeps the catalogue' do
      Granblue::GoldenFixture.load(fixture, mode: :replace)
      weapons = Weapon.count

      party = Granblue::GoldenFixture.load(fixture, mode: :party)

      expect(Party.where(shortcode: code).count).to eq(1)
      expect(party.weapons.count).to eq(fixture['tables']['grid_weapons'].size)
      expect(Weapon.count).to eq(weapons)
    end

    it 'refuses when the catalogue lacks a row the party uses' do
      Granblue::GoldenFixture.load(fixture, mode: :replace)
      missing = fixture['tables']['grid_weapons'].first['weapon_id']
      ActiveRecord::Base.connection.execute('SET LOCAL session_replication_role = replica')
      Weapon.where(id: missing).delete_all
      ActiveRecord::Base.connection.execute('SET LOCAL session_replication_role = DEFAULT')

      expect { Granblue::GoldenFixture.load(fixture, mode: :party) }
        .to raise_error(Granblue::GoldenFixture::Error, /weapons #{missing}/)
    end

    it 'adds missing catalogue rows in :missing mode' do
      Granblue::GoldenFixture.load(fixture, mode: :replace)
      missing = fixture['tables']['grid_weapons'].first['weapon_id']
      ActiveRecord::Base.connection.execute('SET LOCAL session_replication_role = replica')
      Weapon.where(id: missing).delete_all
      ActiveRecord::Base.connection.execute('SET LOCAL session_replication_role = DEFAULT')

      Granblue::GoldenFixture.load(fixture, mode: :missing)

      expect(Weapon.exists?(missing)).to be(true)
    end
  end
end
