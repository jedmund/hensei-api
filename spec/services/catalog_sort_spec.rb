# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogSort do
  def order_sql(relation)
    relation.to_sql[/ORDER BY (.*)\z/, 1]
  end

  describe '.name_column' do
    it 'picks the Japanese name for ja and the English name otherwise' do
      expect(described_class.name_column('ja')).to eq(:name_jp)
      expect(described_class.name_column('en')).to eq(:name_en)
      expect(described_class.name_column(nil)).to eq(:name_en)
    end
  end

  describe 'ITEMS' do
    it 'sorts by the language name column, then id' do
      sql = order_sql(described_class::ITEMS.apply(Weapon.all, 'name', 'desc', 'ja'))
      expect(sql).to eq('"weapons"."name_jp" DESC, "weapons"."id" ASC')
    end

    it 'sorts ascending unless asked for desc' do
      sql = order_sql(described_class::ITEMS.apply(Summon.all, 'last_updated', nil, 'en'))
      expect(sql).to eq('"summons"."latest_date" ASC, "summons"."id" ASC')
    end

    it 'leaves an unknown key unordered' do
      expect(described_class::ITEMS.apply(Character.all, 'nonsense', 'asc', 'en').to_sql).not_to include('ORDER BY')
    end
  end

  describe 'JOBS' do
    it 'keeps in-row order ascending when sorting by row' do
      sql = order_sql(described_class::JOBS.apply(Job.all, 'row', 'desc', 'en'))
      expect(sql).to eq('"jobs"."row" DESC, "jobs"."order" ASC, "jobs"."id" ASC')
    end

    it 'sorts by the first proficiency' do
      sql = order_sql(described_class::JOBS.apply(Job.all, 'proficiency', 'asc', 'en'))
      expect(sql).to eq('"jobs"."proficiency1" ASC, "jobs"."id" ASC')
    end

    it 'falls back to row, order and id for an unknown key' do
      sql = order_sql(described_class::JOBS.apply(Job.all, nil, 'desc', 'ja'))
      expect(sql).to eq('"jobs"."row" ASC, "jobs"."order" ASC, "jobs"."id" ASC')
    end
  end
end
