# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BackfillWikiFetchDates' do
  include CharacterSourceColumns
  include ItemSourceColumns

  let(:migration_class) do
    require Rails.root.join('db/data/20261016100003_backfill_wiki_fetch_dates') unless defined?(BackfillWikiFetchDates)
    BackfillWikiFetchDates
  end
  let(:backfill_at) { Time.utc(2026, 10, 15) }

  # The columns themselves: the models read their sources now (D35); this migration ran on the columns before.
  def stamps(record)
    record.class.where(id: record.id).pick(Arel.sql('wiki_raw_fetched_at'), Arel.sql('wiki_raw_jp_fetched_at'))
  end

  def set_columns(record, **values)
    record.class.where(id: record.id).update_all(values)
  end

  it 'dates stored wikitext that has no fetch date and keeps real dates' do
    real = Time.utc(2026, 6, 17, 3)
    dated = create(:weapon).tap { |w| set_columns(w, wiki_raw: '{{W}}', wiki_raw_fetched_at: real, wiki_raw_jp: '<html/>') }
    undated = create(:summon).tap { |s| set_columns(s, wiki_raw: '{{S}}', wiki_raw_jp: nil) }
    jp_only = create(:character).tap { |c| set_columns(c, wiki_raw: nil, wiki_raw_jp: '<html/>') }
    empty = create(:character).tap { |c| set_columns(c, wiki_raw: '', wiki_raw_jp: nil) }

    migration_class.new.up

    expect(stamps(dated)).to eq([real, backfill_at])
    expect(stamps(undated)).to eq([backfill_at, nil])
    expect(stamps(jp_only)).to eq([nil, backfill_at])
    expect(stamps(empty)).to eq([nil, nil])
  end
end
