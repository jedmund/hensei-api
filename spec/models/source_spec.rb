# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Source do
  let(:owner) { create(:weapon) }
  let(:fetched_at) { Time.zone.parse('2026-10-20 12:00') }

  describe '.put' do
    it 'stores a text body with its sha256 and fetch time' do
      result = described_class.put(owner, :wiki_raw, '{{Weapon}}', fetched_at: fetched_at)

      expect(result.status).to eq(:created)
      expect(result).to be_changed
      expect(result.source).to have_attributes(owner: owner, kind: 'wiki_raw', key: '', body: '{{Weapon}}',
                                               sha256: Digest::SHA256.hexdigest('{{Weapon}}'), fetched_at: fetched_at)
    end

    it 'marks a confirmed body as updated, without rewriting it' do
      source = travel_to(1.day.ago) { described_class.put(owner, :wiki_raw, '{{Weapon}}', fetched_at: fetched_at).source }

      expect { described_class.put(owner, :wiki_raw, '{{Weapon}}', fetched_at: fetched_at + 1.day) }
        .to(change { source.reload.updated_at })
      expect { described_class.put(owner, :wiki_raw, '{{Weapon}}', fetched_at: nil) }
        .not_to(change { source.reload.updated_at })
    end

    it 'leaves an unchanged body alone and only moves fetched_at forward' do
      described_class.put(owner, :wiki_raw, '{{Weapon}}', fetched_at: fetched_at)
      source = described_class.fetch(owner, :wiki_raw)

      result = described_class.put(owner, :wiki_raw, '{{Weapon}}', fetched_at: fetched_at + 1.day)
      expect(result.status).to eq(:unchanged)
      expect(result).not_to be_changed
      expect(source.reload.fetched_at).to eq(fetched_at + 1.day)
      expect(source.body).to eq('{{Weapon}}')

      described_class.put(owner, :wiki_raw, '{{Weapon}}', fetched_at: fetched_at)
      expect(source.reload.fetched_at).to eq(fetched_at + 1.day)
    end

    it 'replaces a changed body in the same row' do
      first = described_class.put(owner, :wiki_raw, '{{Weapon}}').source
      result = described_class.put(owner, :wiki_raw, '{{Weapon|new=1}}')

      expect(result.status).to eq(:changed)
      expect(result.source.id).to eq(first.id)
      expect(described_class.count).to eq(1)
      expect(described_class.read(owner, :wiki_raw)).to eq('{{Weapon|new=1}}')
    end

    it 'removes the row for a blank value' do
      described_class.put(owner, :wiki_raw, '{{Weapon}}')

      expect(described_class.put(owner, :wiki_raw, '').status).to eq(:removed)
      expect(described_class.put(owner, :wiki_raw, nil).status).to eq(:absent)
      expect(described_class.count).to eq(0)
    end

    it 'stores JSON canonically, so key order is not a change' do
      described_class.put(owner, :game_raw_en, { 'b' => 1, 'a' => { 'd' => [2, { 'f' => 1, 'e' => 0 }], 'c' => nil } })
      source = described_class.fetch(owner, :game_raw_en)

      expect(source.body).to eq('{"a":{"c":null,"d":[2,{"e":0,"f":1}]},"b":1}')
      expect(source.value).to eq('a' => { 'c' => nil, 'd' => [2, { 'e' => 0, 'f' => 1 }] }, 'b' => 1)
      expect(described_class.put(owner, :game_raw_en, { a: { d: [2, { e: 0, f: 1 }], c: nil }, b: 1 }).status)
        .to eq(:unchanged)
    end

    it 'treats an empty payload as nothing to store' do
      expect(described_class.put(owner, :game_raw_en, {}).status).to eq(:absent)
    end

    it 'keeps owners, kinds and keys apart' do
      other = create(:weapon)
      described_class.put(owner, :wiki_raw, 'mine')
      described_class.put(other, :wiki_raw, 'theirs')
      described_class.put(owner, :wiki_raw_jp, '<div id="body">jp</div>')
      described_class.put(nil, :wiki_status_list, 'list', key: 'Module:StatusList')
      described_class.put(nil, :wiki_status_list, 'other list', key: 'Module:Other')

      expect(described_class.read(owner, :wiki_raw)).to eq('mine')
      expect(described_class.read(other, :wiki_raw)).to eq('theirs')
      expect(described_class.read(owner, :wiki_raw_jp)).to eq('<div id="body">jp</div>')
      expect(described_class.read(nil, :wiki_status_list, key: 'Module:StatusList')).to eq('list')
      expect(described_class.read(nil, :wiki_status_list)).to be_nil
      expect(described_class.count).to eq(5)
    end

    it 'refuses an unknown kind' do
      expect { described_class.put(owner, :html, 'x') }.to raise_error(ArgumentError, /unknown source kind/)
    end
  end

  describe 'constraints' do
    it 'rejects a second row for the same owner, kind and key' do
      described_class.put(owner, :wiki_raw, 'a')
      duplicate = described_class.new(owner: owner, kind: 'wiki_raw', key: '', body: 'b', sha256: 'x')

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'rejects a second shared row for the same kind and key' do
      described_class.put(nil, :wiki_status_list, 'a', key: 'k')
      duplicate = described_class.new(kind: 'wiki_status_list', key: 'k', body: 'b', sha256: 'x')

      expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it 'rejects a kind outside the list in the database' do
      row = described_class.new(kind: 'nope', body: 'b', sha256: 'x')
      expect { row.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid, /sources_kind/)
    end
  end

  describe '.without_body' do
    it 'loads everything but the body' do
      described_class.put(owner, :wiki_raw, '{{Weapon}}')
      row = described_class.without_body.first

      expect(row.sha256).to eq(Digest::SHA256.hexdigest('{{Weapon}}'))
      expect(row.has_attribute?(:body)).to be(false)
    end
  end
end
