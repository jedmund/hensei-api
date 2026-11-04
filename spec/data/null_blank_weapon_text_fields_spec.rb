# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('db/data/20261101120000_null_blank_weapon_text_fields')

RSpec.describe NullBlankWeaponTextFields do
  subject(:migration) { described_class.new }

  let(:stamp) { Time.zone.parse('2026-01-01 00:00') }

  let!(:blank) do
    stored({ wiki_en: '', wiki_ja: '', gamewith: '', kamigame: '', name_jp: '', recruits: '', forged_from: '' })
  end
  let!(:filled) { stored({ wiki_en: 'Page', wiki_ja: '武器/ページ', gamewith: '123', kamigame: 'x', name_jp: '武器' }) }

  before { allow(migration).to receive(:say) }

  # Stored as the legacy rows are: update_columns skips validations and normalization.
  def stored(attributes, *traits)
    weapon = create(:weapon, *traits)
    weapon.update_columns(attributes.merge(updated_at: stamp))
    weapon
  end

  it 'sets blank text fields to NULL and stamps updated_at, rerunnably' do
    2.times do
      migration.up
      expect(blank.reload).to have_attributes(wiki_en: nil, wiki_ja: nil, gamewith: nil, kamigame: nil,
                                              name_jp: nil, recruits: nil, forged_from: nil)
    end
    expect(blank.updated_at).to be > stamp
  end

  it 'leaves filled fields and their updated_at alone' do
    migration.up
    expect(filled.reload).to have_attributes(wiki_en: 'Page', wiki_ja: '武器/ページ', gamewith: '123',
                                             kamigame: 'x', name_jp: '武器', updated_at: stamp)
  end
end
