# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Parsers::CuratedStatusCategories do
  def load(entries)
    file = Tempfile.new(['categories', '.json'])
    file.write(entries.is_a?(String) ? entries : JSON.generate(entries))
    file.close
    described_class.load(file.path)
  ensure
    file&.unlink
  end

  it 'maps normalized names to categories' do
    curated = load([{ name_en: 'Tuning ', category: 'debuff', reason: 'Raised on foes' },
                    { name_en: 'Sun-Touched  Paradise', category: 'field', reason: 'To the field' }])
    expect(curated).to eq('tuning' => { category: 'debuff', game_status_id: nil },
                          'sun-touched paradise' => { category: 'field', game_status_id: nil })
  end

  it 'reads a display id, or "none", with or without a category' do
    curated = load([{ name_en: 'Charge Boost', game_status_id: 'none', reason: 'An instant effect' },
                    { name_en: '40% DMG Cut', game_status_id: '1019_0_40', category: 'buff', reason: 'x' }])
    expect(curated).to eq('charge boost' => { category: nil, game_status_id: 'none' },
                          '40% dmg cut' => { category: 'buff', game_status_id: '1019_0_40' })
  end

  it 'rejects a malformed display id, or an entry that sets nothing' do
    expect { load([{ name_en: 'Veil', game_status_id: 'status_1003', reason: 'x' }]) }
      .to raise_error(described_class::Invalid, /game_status_id "status_1003"/)
    expect { load([{ name_en: 'Veil', reason: 'x' }]) }.to raise_error(described_class::Invalid, /neither/)
  end

  describe 'entries scoped to characters' do
    def scoped(entries)
      file = Tempfile.new(['categories', '.json'])
      file.write(JSON.generate(entries))
      file.close
      [described_class.load(file.path), described_class.scoped(file.path)]
    ensure
      file&.unlink
    end

    let(:entries) do
      [{ name_en: 'Max HP Lowered', category: 'debuff', reason: 'x' },
       { name_en: 'Max HP Lowered', category: 'buff', characters: ['3040291000'], reason: 'a buff for Silva' }]
    end

    it 'keeps them out of the plain entries and applies them only to those characters' do
      curated, by_character = scoped(entries)
      expect(curated).to eq('max hp lowered' => { category: 'debuff', game_status_id: nil })
      expect(by_character).to eq('max hp lowered' => { '3040291000' => 'buff' })
      expect(described_class.category_for(curated, by_character, 'max hp lowered', '3040291000')).to eq('buff')
      expect(described_class.category_for(curated, by_character, 'max hp lowered', '3040001000')).to eq('debuff')
      expect(described_class.category_for(curated, by_character, 'max hp lowered', nil)).to eq('debuff')
    end

    it 'needs granblue ids and a category, and no display id' do
      expect { scoped([{ name_en: 'X', category: 'buff', characters: [], reason: 'x' }]) }
        .to raise_error(described_class::Invalid, /granblue ids/)
      expect { scoped([{ name_en: 'X', game_status_id: '1020', characters: ['3040291000'], reason: 'x' }]) }
        .to raise_error(described_class::Invalid, /no category/)
      expect { scoped([{ name_en: 'X', category: 'buff', game_status_id: '1020', characters: ['3040291000'], reason: 'x' }]) }
        .to raise_error(described_class::Invalid, /game_status_id/)
    end
  end

  it 'treats a missing file as nothing curated' do
    expect(described_class.load('/nonexistent/categories.json')).to eq({})
  end

  it 'loads the shipped data/statuses/categories.json without error' do
    expect { described_class.load }.not_to raise_error
    expect(described_class.load).to be_a(Hash)
  end

  it 'digests the committed file for the build fingerprint' do
    expect(described_class.sha256).to eq(Digest::SHA256.file(described_class::DEFAULT_PATH).hexdigest)
    expect(described_class.sha256('/nonexistent.json')).to eq('-')
  end

  it 'treats an empty file as nothing curated' do
    expect(load('')).to eq({})
  end

  it 'rejects an unknown category' do
    expect { load([{ name_en: 'Veil', category: 'special', reason: 'x' }]) }
      .to raise_error(described_class::Invalid, /"Veil" has category "special"/)
  end

  it 'rejects an entry without a reason' do
    expect { load([{ name_en: 'Veil', category: 'buff' }]) }.to raise_error(described_class::Invalid, /no reason/)
  end

  it 'rejects a name listed twice, whatever its case' do
    expect { load([{ name_en: 'Veil', category: 'buff', reason: 'x' }, { name_en: 'veil', category: 'buff', reason: 'y' }]) }
      .to raise_error(described_class::Invalid, /listed twice/)
  end

  it 'rejects a file that is not a list' do
    expect { load('{"name_en": "Veil"}') }.to raise_error(described_class::Invalid, /expected a list/)
    expect { load('[') }.to raise_error(described_class::Invalid)
  end
end
