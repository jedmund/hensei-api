# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::Coverage do
  let(:today) { Date.new(2026, 10, 20) }
  let(:storage) { instance_double(AwsService) }

  let!(:complete) do
    create(:character, granblue_id: '3040000001', name_en: 'Complete', rarity: 3, wiki_raw: '{{Character}}',
                       wiki_raw_fetched_at: today - 5, wiki_raw_jp: '<html/>',
                       game_raw_en: { 'id' => '3040000001' }, game_raw_jp: { 'id' => '3040000001' })
  end
  let!(:no_skills) do
    create(:character, granblue_id: '3040000002', name_en: 'New', rarity: 3, wiki_raw: '{{Character}}',
                       wiki_raw_fetched_at: today - 100, game_raw_en: nil)
  end
  let!(:unreleased) do
    create(:character, granblue_id: '3040000003', name_en: 'Soon', rarity: 2, release_date: today + 3, wiki_raw: nil, wiki_en: '')
  end
  let!(:json_null) do
    create(:character, granblue_id: '3030000004', name_en: 'Nulled', rarity: 2, wiki_raw: '{{Character}}',
                       wiki_raw_fetched_at: nil, game_raw_en: nil)
  end
  let!(:style_row) do
    create(:character, granblue_id: '3040000001', name_en: 'Complete', style_swap: true, rarity: 3,
                       wiki_raw: '{{Character}}', wiki_raw_fetched_at: today - 40)
  end

  before do
    put_icon_snapshot([
      { granblue_id: '3030000004', style: 1, kind: 'ability', position: 1, ordinal: 1, name_en: 'Kept',
        game_icon: '100_1' }
    ])

    ability = create(:character_skill, character: complete, kind: :ability, position: 1)
    create(:character_skill_version, character_skill: ability, ordinal: 1, name_en: 'Strike', name_jp: 'ストライク', game_icon: '1_1')
    create(:character_skill_version, character_skill: ability, ordinal: 2, name_en: 'Strike II', name_jp: nil, game_icon: nil)
    support = create(:character_skill, :support, character: complete, position: 1)
    create(:character_skill_version, character_skill: support, ordinal: 1, name_en: 'Aura', name_jp: 'オーラ', game_icon: nil)

    nulled = create(:character_skill, character: json_null, kind: :ability, position: 1)
    create(:character_skill_version, character_skill: nulled, ordinal: 1, name_en: 'Kept', name_jp: 'a', game_icon: '100_1')
    create(:character_skill_version, character_skill: nulled, ordinal: 2, name_en: 'Renamed', name_jp: 'b', game_icon: '200_1')
  end

  # The test database carries seeded characters; the report looks at this spec's only.
  let(:own_ids) { %w[3040000001 3040000002 3040000003 3030000004] }

  def coverage(**)
    described_class.new(today: today, ids: own_ids, **)
  end

  def row(report, key) = report.rows.find { |r| r.key == key }

  def ids_in(report, key) = row(report, key).items.map { |item| [item.granblue_id, item.style] }

  it 'counts released characters without skills, by character row' do
    report = coverage
    expect(ids_in(report, :no_skills)).to contain_exactly(['3040000002', 1], ['3040000001', 2])
    expect(ids_in(report, :no_skills_unreleased)).to eq([['3040000003', 1]])
    expect(row(report, :no_skills).by_rarity(3)).to eq(2)
  end

  it 'reports blank wiki_raw, noting rows that have no page title' do
    item = row(coverage, :wiki_raw_blank).items.sole
    expect([item.granblue_id, item.detail]).to eq(['3040000003', 'no wiki_en (needs a page title)'])
  end

  it 'buckets wiki_raw_fetched_at by age' do
    report = coverage
    expect(ids_in(report, :wiki_raw_fetched_never)).to eq([['3030000004', 1]])
    expect(ids_in(report, :wiki_raw_fetched_old)).to eq([['3040000002', 1]])
    expect(ids_in(report, :wiki_raw_fetched_mid)).to eq([['3040000001', 2]])
    expect(ids_in(report, :wiki_raw_fetched_recent)).to eq([['3040000001', 1]])
  end

  it 'treats JSON null game data as missing' do
    expect(ids_in(coverage, :no_game_raw_en)).to include(['3030000004', 1])
    expect(ids_in(coverage, :no_game_raw_en)).not_to include(['3040000001', 1])
    expect(row(coverage, :no_game_raw_jp).count).to eq(4)
  end

  it 'reports style rows' do
    report = coverage
    expect(ids_in(report, :style_rows)).to eq([['3040000001', 2]])
    expect(ids_in(report, :style_no_skills)).to eq([['3040000001', 2]])
    expect(ids_in(report, :style_no_game_raw_en)).to eq([['3040000001', 2]])
  end

  it 'reports versions without name_jp and ability versions without game_icon' do
    report = coverage
    expect(row(report, :versions_no_name_jp).items.map(&:detail)).to eq(['ability 1.2 Strike II'])
    expect(row(report, :ability_versions_no_game_icon).items.map(&:detail)).to eq(['ability 1.2 Strike II'])
    expect(row(report, :support_versions_no_game_icon).items.map(&:detail)).to eq(['support 1.1 Aura'])
  end

  it 'lists ability icons that only the wiki stem can explain' do
    # Complete has game data (its icon is the game's); Nulled's "Kept" is in the snapshot.
    expect(row(coverage, :ability_versions_wiki_stem_only).items.map(&:detail)).to eq(['ability 1.2 Renamed [200_1]'])
  end

  it 'narrows every row to ids, both style rows included' do
    report = coverage(ids: ['3040000001'])
    expect(row(report, :characters).count).to eq(2)
    expect(ids_in(report, :no_skills)).to eq([['3040000001', 2]])
    expect(row(report, :versions).count).to eq(3)
  end

  it 'prints a table with totals by rarity' do
    expect { coverage.print }.to output(/ids: 3040000001.*Released, no skills\s+2\s+0\s+0\s+2\s+2/m).to_stdout
  end

  it 'writes the gap rows to CSV' do
    rows = CSV.parse(coverage.to_csv, headers: true)
    expect(rows.map { |r| r['check'] }.uniq).to all(satisfy { |key| row(coverage, key.to_sym).gap })
    expect(rows.find { |r| r['check'] == 'ability_versions_wiki_stem_only' }.to_h)
      .to include('granblue_id' => '3030000004', 'style' => '1', 'name_en' => 'Nulled', 'rarity' => 'SR')
    expect(rows.map { |r| r['check'] }).not_to include('characters', 'wiki_raw_fetched_recent')
  end

  describe 's3: true' do
    it 'HEAD-checks each distinct stem once, through AwsService, waiting between requests' do
      allow(storage).to receive(:file_exists?) { |key| key != 'icons/abilities/200_1.png' }
      waits = []
      report = coverage(check_bucket: true, storage: storage, s3_delay: 0.1, sleeper: ->(s) { waits << s })

      item = row(report, :ability_stems_missing_from_bucket).items.sole
      expect(item.detail).to eq('200_1 (1 versions, 1 characters)')
      expect(storage).to have_received(:file_exists?).exactly(3).times
      expect(waits).to eq([0.1, 0.1])
    end

    it 'leaves the bucket alone without s3' do
      allow(AwsService).to receive(:new)
      expect(row(coverage, :ability_stems_missing_from_bucket)).to be_nil
      expect(AwsService).not_to have_received(:new)
    end
  end
end
