# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BackfillWikiFetchDates' do
  let(:migration_class) do
    require Rails.root.join('db/data/20261016100003_backfill_wiki_fetch_dates') unless defined?(BackfillWikiFetchDates)
    BackfillWikiFetchDates
  end
  let(:backfill_at) { Time.utc(2026, 10, 15) }

  def stamps(character)
    Character.where(id: character.id).pick(Arel.sql('wiki_raw_fetched_at'), Arel.sql('wiki_raw_jp_fetched_at'))
  end

  it 'dates stored wikitext that has no fetch date and keeps real dates' do
    real = Time.utc(2026, 6, 17, 3)
    dated = create(:weapon, wiki_raw: '{{W}}', wiki_raw_fetched_at: real, wiki_raw_jp: '<html/>')
    undated = create(:summon, wiki_raw: '{{S}}', wiki_raw_jp: nil)
    # Characters' columns are no longer written through the model (D35); this migration ran on them before.
    jp_only = create(:character).tap { |c| Character.where(id: c.id).update_all(wiki_raw: nil, wiki_raw_jp: '<html/>') }
    empty = create(:character).tap { |c| Character.where(id: c.id).update_all(wiki_raw: '', wiki_raw_jp: nil) }

    migration_class.new.up

    expect(dated.reload).to have_attributes(wiki_raw_fetched_at: real, wiki_raw_jp_fetched_at: backfill_at)
    expect(undated.reload).to have_attributes(wiki_raw_fetched_at: backfill_at, wiki_raw_jp_fetched_at: nil)
    expect(stamps(jp_only)).to eq([nil, backfill_at])
    expect(stamps(empty)).to eq([nil, nil])
  end
end
