# frozen_string_literal: true

require 'rails_helper'

# The test database holds the canonical seed rows, so these examples assert on
# the records they create: whether each is in the results, and the order they
# come back in relative to each other.
RSpec.describe 'Api::V1::Search', type: :request do
  def search(path, body = {}, per = 50)
    url = path ? "/api/v1/search/#{path}" : '/api/v1/search'
    post url, params: { search: body }.to_json,
              headers: { 'Content-Type' => 'application/json', 'X-Per-Page' => per.to_s }
    response.parsed_body
  end

  def result_ids
    response.parsed_body['results'].map { |result| result['id'] }
  end

  # The given records' ids in the order the results list them
  def order_of(*records)
    result_ids & records.flatten.map(&:id)
  end

  describe 'GET /api/v1/search/suggestions' do
    it 'returns random suggestions' do
      get '/api/v1/search/suggestions', params: { count: 6 }
      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['suggestions']).to be_an(Array)
      expect(body['suggestions'].length).to be <= 6
    end

    it 'clamps count to valid range' do
      get '/api/v1/search/suggestions', params: { count: 100 }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['suggestions'].length).to be <= 30
    end

    it 'returns at least one suggestion for a zero count' do
      get '/api/v1/search/suggestions', params: { count: 0 }
      expect(response.parsed_body['suggestions'].length).to eq(1)
    end
  end

  describe 'POST /api/v1/search (all)' do
    let!(:zyx_character) { create(:character, name_en: 'Zyxcharacter', name_jp: 'ズィクスキャラ') }
    let!(:zyx_weapon) { create(:weapon, name_en: 'Zyxweapon', name_jp: 'ズィクス武器') }

    def searchable_ids
      response.parsed_body['results'].map { |result| result['searchable_id'] }
    end

    it 'returns multisearch documents with the searchable record' do
      search(nil, query: 'Zyxcharacter')
      expect(response).to have_http_status(:ok)
      result = response.parsed_body['results'].find { |r| r['searchable_id'] == zyx_character.id }
      expect(result).to include('searchable_type' => 'Character', 'granblue_id' => zyx_character.granblue_id,
                                'name_en' => 'Zyxcharacter', 'name_jp' => 'ズィクスキャラ')
    end

    it 'falls back to a prefix search in English when the trigram search finds fewer than five' do
      search(nil, query: 'Zyx', locale: 'en')
      expect(searchable_ids).to include(zyx_character.id, zyx_weapon.id)
    end

    it 'prefix-searches Japanese names in the ja locale' do
      search(nil, query: 'ズィクス', locale: 'ja')
      expect(searchable_ids).to include(zyx_character.id, zyx_weapon.id)
    end

    it 'treats the jp locale as Japanese' do
      search(nil, query: 'ズィクス', locale: 'jp')
      expect(searchable_ids).to include(zyx_character.id, zyx_weapon.id)
    end

    it 'leaves out excluded granblue ids' do
      search(nil, query: 'Zyx', exclude: [zyx_weapon.granblue_id])
      expect(searchable_ids).to include(zyx_character.id)
      expect(searchable_ids).not_to include(zyx_weapon.id)
    end

    it 'returns at most ten results, whatever the page size' do
      create_list(:summon, 6, name_en: 'Zyxsummon')
      create_list(:summon, 6, name_en: 'Zyxsummon')
      search(nil, { query: 'Zyxsummon' }, 50)
      expect(response.parsed_body['results'].length).to eq(10)
    end
  end

  describe 'POST /api/v1/search/characters' do
    it 'returns characters without query' do
      search('characters', page: 1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end

    it 'returns characters without a search key' do
      post '/api/v1/search/characters', params: {}.to_json, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end

    it 'ignores filters that are not a hash' do
      character = create(:character)
      search('characters', filters: 'x')
      expect(response).to have_http_status(:ok)
      expect(result_ids).to include(character.id)
    end

    # Regression: sorting by name in a Japanese locale must order by the real
    # name_jp column (was a 500: PG undefined column name_ja).
    it 'does not error when sorting by name in ja locale' do
      create(:character)
      search('characters', page: 1, locale: 'ja', sort: 'name', order: 'asc')
      expect(response).to have_http_status(:ok)
    end

    it 'filters by element and returns only matching results' do
      search('characters', filters: { element: [4] }, page: 1)
      expect(response).to have_http_status(:ok)

      results = response.parsed_body['results']
      results.each do |r|
        expect(r['element']).to eq(4)
      end
    end

    context 'when filtering by proficiency' do
      # Sabre = 1, Dagger = 2, Axe = 3
      let!(:sabre_primary) { create(:character, proficiency1: 1, proficiency2: nil) }
      let!(:sabre_secondary) { create(:character, proficiency1: 4, proficiency2: 1) }
      let!(:no_sabre) { create(:character, proficiency1: 2, proficiency2: 4) }

      it 'matches characters with the proficiency in either slot' do
        search('characters', filters: { proficiency1: [1] }, page: 1)
        expect(response).to have_http_status(:ok)

        ids = result_ids
        expect(ids).to include(sabre_primary.id, sabre_secondary.id)
        expect(ids).not_to include(no_sabre.id)
      end
    end

    context 'with column filters' do
      let!(:match) { create(:character, rarity: 2, element: 5, season: 2, gender: 1) }
      let!(:other) { create(:character, rarity: 3, element: 2, season: nil, gender: 0) }

      %w[rarity element season gender].each do |filter|
        it "filters by #{filter}" do
          search('characters', filters: { filter => [match.public_send(filter)] })
          expect(result_ids).to include(match.id)
          expect(result_ids).not_to include(other.id)
        end
      end

      it 'combines filters' do
        search('characters', filters: { rarity: [2], element: [2] })
        expect(result_ids).not_to include(match.id, other.id)
      end

      it 'ignores empty filter values' do
        search('characters', filters: { rarity: [], element: '', season: nil, gender: [], race: [], series: [] })
        expect(result_ids).to include(match.id, other.id)
      end
    end

    it 'matches race in either slot' do
      human_erune = create(:character, race1: 1, race2: 2)
      erune = create(:character, race1: 2, race2: nil)
      draph = create(:character, race1: 4, race2: nil)

      search('characters', filters: { race: ['2'] })
      expect(result_ids).to include(human_erune.id, erune.id)
      expect(result_ids).not_to include(draph.id)
    end

    it 'filters by character series' do
      series = create(:character_series)
      member = create(:character)
      create(:character_series_membership, character: member, character_series: series)
      outsider = create(:character)

      search('characters', filters: { series: [series.id] })
      expect(result_ids).to eq([member.id])
      expect(result_ids).not_to include(outsider.id)
    end

    it 'combines proficiency, race and series filters' do
      series = create(:character_series)
      both = create(:character, proficiency1: 3, race1: 4)
      wrong_race = create(:character, proficiency1: 3, race1: 1)
      [both, wrong_race].each { |c| create(:character_series_membership, character: c, character_series: series) }

      search('characters', filters: { proficiency1: [3], race: [4], series: [series.id] })
      expect(result_ids).to eq([both.id])
    end

    it 'leaves out excluded ids' do
      kept = create(:character)
      excluded = create(:character)
      search('characters', exclude: [excluded.id])
      expect(result_ids).to include(kept.id)
      expect(result_ids).not_to include(excluded.id)
    end

    context 'with a text query' do
      let!(:alpha) do
        create(:character, name_en: 'Zyxalpha', name_jp: 'ズィクスアルファ', nicknames_en: ['qwvnick'], nicknames_jp: ['くわぶ'])
      end
      let!(:beta) { create(:character, name_en: 'Zyxbeta', name_jp: 'ズィクスベータ') }

      it 'searches English names and nicknames' do
        # The English search is fuzzy (trigram), so close names match too
        search('characters', query: 'Zyxalpha')
        expect(result_ids.first).to eq(alpha.id)

        search('characters', query: 'qwvnick')
        expect(result_ids).to eq([alpha.id])
      end

      it 'searches Japanese names and nicknames in the ja locale' do
        search('characters', query: 'ズィクスアルファ', locale: 'ja')
        expect(result_ids).to eq([alpha.id])

        search('characters', query: 'くわぶ', locale: 'ja')
        expect(result_ids).to eq([alpha.id])
      end

      it 'treats the jp locale as Japanese' do
        search('characters', query: 'ズィクスベータ', locale: 'jp')
        expect(result_ids).to eq([beta.id])
      end

      it 'does not search English names in the ja locale' do
        search('characters', query: 'Zyxalpha', locale: 'ja')
        expect(result_ids).to be_empty
      end

      it 'ignores a one-character query' do
        search('characters', query: 'Z')
        expect(result_ids).to include(alpha.id, beta.id)
        expect(response.parsed_body['meta']['count']).to eq(Character.count)
      end

      it 'applies filters to the text search' do
        search('characters', query: 'Zyx', filters: { proficiency1: [alpha.proficiency1] }, exclude: [beta.id])
        expect(result_ids).to eq([alpha.id])
      end
    end

    context 'when ordering' do
      let!(:older) { create(:character, name_en: 'Bravo', name_jp: 'あ', element: 3, rarity: 1, release_date: '2098-01-01') }
      let!(:newer) { create(:character, name_en: 'Alpha', name_jp: 'う', element: 2, rarity: 3, release_date: '2099-01-01') }
      let!(:middle) { create(:character, name_en: 'Charlie', name_jp: 'い', element: 1, rarity: 2, release_date: '2098-06-01') }
      let(:mine) { [older, newer, middle] }

      it 'lists the newest first by default' do
        search('characters')
        expect(result_ids.first(3)).to eq([newer, middle, older].map(&:id))
      end

      it 'breaks latest_date ties by id' do
        tied = create_list(:character, 2, release_date: '2100-01-01')
        search('characters')
        expect(result_ids.first(2)).to eq(tied.map(&:id).sort)
      end

      it 'sorts by English name' do
        search('characters', sort: 'name', order: 'asc')
        expect(order_of(mine)).to eq([newer, older, middle].map(&:id))

        search('characters', sort: 'name', order: 'desc')
        expect(order_of(mine)).to eq([middle, older, newer].map(&:id))
      end

      it 'sorts by Japanese name in the ja locale' do
        search('characters', sort: 'name', order: 'asc', locale: 'ja')
        expect(order_of(mine)).to eq([older, middle, newer].map(&:id))

        search('characters', sort: 'name', order: 'desc', locale: 'jp')
        expect(order_of(mine)).to eq([newer, middle, older].map(&:id))
      end

      it 'sorts ascending unless the order is desc' do
        search('characters', sort: 'name', order: 'sideways')
        expect(order_of(mine)).to eq([newer, older, middle].map(&:id))
      end

      it 'sorts by element, rarity and last update' do
        search('characters', sort: 'element')
        expect(order_of(mine)).to eq([middle, newer, older].map(&:id))

        search('characters', sort: 'rarity', order: 'desc')
        expect(order_of(mine)).to eq([newer, middle, older].map(&:id))

        search('characters', sort: 'last_updated', order: 'asc')
        expect(order_of(mine)).to eq([older, middle, newer].map(&:id))
      end

      it 'breaks sort ties by id' do
        tied = create_list(:character, 2, name_en: 'Aaaa tie')
        search('characters', sort: 'name')
        expect(result_ids.first(2)).to eq(tied.map(&:id).sort)
      end

      # pg_search orders by rank, then id, so a sort after it changes nothing
      it 'keeps the text search rank order when sorting' do
        create(:character, name_en: 'Qqzz B')
        create(:character, name_en: 'Qqzz A')
        search('characters', query: 'Qqzz')
        ranked = result_ids

        search('characters', query: 'Qqzz', sort: 'name', order: 'desc')
        expect(result_ids).to eq(ranked)
        search('characters', query: 'Qqzz', sort: 'name', order: 'asc')
        expect(result_ids).to eq(ranked)
      end
    end

    describe 'pagination' do
      let!(:characters) { create_list(:character, 3, release_date: '2099-01-01') }

      it 'pages with the X-Per-Page size and reports the total count' do
        search('characters', { page: 2 }, 2)
        meta = response.parsed_body['meta']
        expect(response.parsed_body['results'].length).to eq(2)
        expect(meta).to eq('count' => Character.count, 'total_pages' => (Character.count / 2.0).ceil, 'per_page' => 2)
        expect(result_ids).to eq([characters.map(&:id).max, Character.order(latest_date: :desc, id: :asc).offset(3).first.id])
      end

      it 'defaults to ten per page' do
        post '/api/v1/search/characters', params: { search: {} }.to_json,
                                          headers: { 'Content-Type' => 'application/json' }
        expect(response.parsed_body['meta']['per_page']).to eq(10)
        expect(response.parsed_body['results'].length).to eq(10)
      end

      it 'returns an empty page past the end' do
        search('characters', page: 99)
        expect(response.parsed_body['results']).to eq([])
        expect(response.parsed_body['meta']['count']).to eq(Character.count)
      end

      it 'counts every match, not just the page' do
        search('characters', { filters: { element: [characters.first.element] } }, 1)
        expect(response.parsed_body['meta']['count']).to eq(Character.where(element: characters.first.element).count)
      end
    end

    it 'renders the dates view' do
      character = create(:character, release_date: '2099-01-01')
      search('characters')
      result = response.parsed_body['results'].first
      expect(result['id']).to eq(character.id)
      expect(result.keys).to include('name', 'granblue_id', 'element', 'rarity', 'release_date')
    end
  end

  describe 'POST /api/v1/search/weapons' do
    it 'returns weapons without query' do
      search('weapons', page: 1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end

    it 'ignores filters that are not a hash' do
      weapon = create(:weapon)
      search('weapons', filters: 'x')
      expect(response).to have_http_status(:ok)
      expect(result_ids).to include(weapon.id)
    end

    context 'with filters' do
      let(:series) { create(:weapon_series) }
      let!(:match) do
        create(:weapon, rarity: 2, element: 5, proficiency: 6, weapon_series: series, extra: true, promotions: [1, 3])
      end
      let!(:other) { create(:weapon, rarity: 3, element: 2, proficiency: 1, extra: false, promotions: [2]) }

      {
        rarity: [2], element: [5], proficiency1: [6], extra: true, promotions: [3, 9]
      }.each do |filter, value|
        it "filters by #{filter}" do
          search('weapons', filters: { filter => value })
          expect(result_ids).to include(match.id)
          expect(result_ids).not_to include(other.id)
        end
      end

      it 'filters by weapon series' do
        search('weapons', filters: { series: [series.id] })
        expect(result_ids).to eq([match.id])
      end

      it 'does not filter on extra false' do
        search('weapons', filters: { extra: false })
        expect(result_ids).to include(match.id, other.id)
      end

      it 'ignores empty filter values' do
        search('weapons', filters: { rarity: [], element: [], proficiency1: [], series: [], promotions: [] })
        expect(result_ids).to include(match.id, other.id)
      end

      it 'applies filters to the text search' do
        match.update!(name_en: 'Zyxblade')
        other.update!(name_en: 'Zyxbow')
        search('weapons', query: 'Zyx', filters: { element: [5] })
        expect(result_ids).to eq([match.id])
      end
    end

    it 'searches English names in en and Japanese names in ja' do
      weapon = create(:weapon, name_en: 'Zyxsword', name_jp: 'ズィクス剣')
      search('weapons', query: 'Zyxsword')
      expect(result_ids).to eq([weapon.id])

      search('weapons', query: 'ズィクス剣', locale: 'ja')
      expect(result_ids).to eq([weapon.id])
    end

    context 'when ordering' do
      let!(:older) { create(:weapon, name_en: 'Bravo', name_jp: 'う', element: 1, release_date: '2098-01-01', flb_date: nil) }
      let!(:newer) { create(:weapon, name_en: 'Charlie', name_jp: 'あ', element: 3, release_date: '2099-01-01', flb_date: nil) }
      let(:mine) { [older, newer] }

      it 'lists the newest first by default' do
        search('weapons')
        expect(result_ids.first(2)).to eq([newer.id, older.id])
      end

      it 'sorts by name in the request locale' do
        search('weapons', sort: 'name')
        expect(order_of(mine)).to eq([older.id, newer.id])

        search('weapons', sort: 'name', locale: 'ja')
        expect(order_of(mine)).to eq([newer.id, older.id])
      end

      it 'sorts by element' do
        search('weapons', sort: 'element', order: 'desc')
        expect(order_of(mine)).to eq([newer.id, older.id])
      end
    end

    it 'pages results' do
      search('weapons', { page: 1 }, 3)
      expect(response.parsed_body['results'].length).to eq(3)
      expect(response.parsed_body['meta']).to eq('count' => Weapon.count, 'total_pages' => (Weapon.count / 3.0).ceil,
                                                 'per_page' => 3)
    end
  end

  describe 'POST /api/v1/search/summons' do
    it 'returns summons without query' do
      search('summons', page: 1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end

    context 'with filters' do
      let(:series) { create(:summon_series) }
      let!(:match) { create(:summon, rarity: 2, element: 5, subaura: true, summon_series: series, promotions: [1, 3]) }
      let!(:other) { create(:summon, rarity: 3, element: 2, subaura: false, promotions: [2]) }

      { rarity: [2], element: [5], subaura: true, promotions: [3] }.each do |filter, value|
        it "filters by #{filter}" do
          search('summons', filters: { filter => value })
          expect(result_ids).to include(match.id)
          expect(result_ids).not_to include(other.id)
        end
      end

      it 'filters by summon series' do
        search('summons', filters: { series: [series.id] })
        expect(result_ids).to eq([match.id])
      end

      it 'does not filter on subaura false' do
        search('summons', filters: { subaura: false })
        expect(result_ids).to include(match.id, other.id)
      end
    end

    # The extension looks summons up by exact name with only a query
    it 'finds a summon by name with no other params' do
      summon = create(:summon, name_en: 'Zyxsummon', name_jp: 'ズィクス召喚')
      search('summons', query: 'Zyxsummon')
      expect(result_ids).to eq([summon.id])

      search('summons', query: 'ズィクス召喚', locale: 'ja')
      expect(result_ids).to eq([summon.id])
    end

    context 'when ordering' do
      let!(:older) { create(:summon, name_en: 'Bravo', name_jp: 'う', rarity: 3, release_date: '2098-01-01', flb_date: nil) }
      let!(:newer) { create(:summon, name_en: 'Charlie', name_jp: 'あ', rarity: 1, release_date: '2099-01-01', flb_date: nil) }
      let(:mine) { [older, newer] }

      it 'lists the newest first by default' do
        search('summons')
        expect(result_ids.first(2)).to eq([newer.id, older.id])
      end

      it 'sorts by name in the request locale' do
        search('summons', sort: 'name')
        expect(order_of(mine)).to eq([older.id, newer.id])

        search('summons', sort: 'name', locale: 'ja')
        expect(order_of(mine)).to eq([newer.id, older.id])
      end

      it 'sorts by rarity' do
        search('summons', sort: 'rarity')
        expect(order_of(mine)).to eq([newer.id, older.id])
      end
    end

    it 'pages results' do
      search('summons', { page: 2 }, 4)
      expect(response.parsed_body['results'].length).to eq(4)
      expect(response.parsed_body['meta']).to eq('count' => Summon.count, 'total_pages' => (Summon.count / 4.0).ceil,
                                                 'per_page' => 4)
    end
  end

  describe 'POST /api/v1/search/jobs' do
    it 'returns jobs without query' do
      create(:job)
      search('jobs', page: 1)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end

    context 'with filters' do
      let!(:row_five) do
        create(:job, row: '5', proficiency1: 3, proficiency2: 4, master_level: false, ultimate_mastery: false,
                     accessory: false)
      end
      let!(:row_four) do
        create(:job, row: '4', proficiency1: 5, proficiency2: 6, master_level: true, ultimate_mastery: true,
                     accessory: true)
      end

      it 'filters by row' do
        search('jobs', filters: { row: ['5'] })
        expect(result_ids).to include(row_five.id)
        expect(result_ids).not_to include(row_four.id)
      end

      it 'matches proficiency in either slot' do
        search('jobs', filters: { proficiency: [3] })
        expect(result_ids).to include(row_five.id)
        expect(result_ids).not_to include(row_four.id)

        search('jobs', filters: { proficiency: ['6'] })
        expect(result_ids).to include(row_four.id)
        expect(result_ids).not_to include(row_five.id)
      end

      # The second proficiency slot is OR'd onto the whole query, so a job
      # whose second proficiency matches is listed whatever its row.
      it 'matches the second proficiency slot regardless of row' do
        search('jobs', filters: { row: ['5'], proficiency: [6] })
        expect(result_ids).to include(row_four.id)
        expect(result_ids).not_to include(row_five.id)
      end

      # The text search joins its rank subquery, so it still limits both slots
      it 'matches the second proficiency slot among text matches, regardless of row' do
        row_four.update!(name_en: 'Zyxjob four')
        row_five.update!(name_en: 'Zyxjob five')
        outsider = create(:job, row: '5', proficiency1: 1, proficiency2: 6)
        search('jobs', query: 'Zyxjob', filters: { row: ['5'], proficiency: [6] })
        expect(result_ids).to eq([row_four.id])
        expect(result_ids).not_to include(outsider.id)
      end

      it 'applies feature flags to both proficiency slots' do
        search('jobs', filters: { proficiency: [4, 6], masterLevel: true })
        expect(result_ids).to include(row_four.id)
        expect(result_ids).not_to include(row_five.id)
      end

      %i[masterLevel ultimateMastery accessory].each do |filter|
        it "filters by #{filter}" do
          search('jobs', filters: { filter => 'true' })
          expect(result_ids).to include(row_four.id)
          expect(result_ids).not_to include(row_five.id)
        end

        it "does not filter on #{filter} false" do
          search('jobs', filters: { filter => false })
          expect(result_ids).to include(row_four.id, row_five.id)
        end
      end
    end

    it 'searches names in the request locale' do
      job = create(:job, name_en: 'Zyxwarrior', name_jp: 'ズィクス戦士')
      search('jobs', query: 'Zyxwarrior')
      expect(result_ids).to eq([job.id])

      search('jobs', query: 'ズィクス戦士', locale: 'ja')
      expect(result_ids).to eq([job.id])
    end

    context 'when ordering' do
      let!(:b) { create(:job, name_en: 'Bzz', name_jp: 'あ', row: '1', order: 9, proficiency1: 3) }
      let!(:a) { create(:job, name_en: 'Azz', name_jp: 'う', row: 'ex1', order: 1, proficiency1: 1) }
      let!(:c) { create(:job, name_en: 'Czz', name_jp: 'い', row: '1', order: 2, proficiency1: 2) }
      let(:mine) { [a, b, c] }

      it 'orders by row, then order, by default' do
        search('jobs')
        expect(order_of(mine)).to eq([c, b, a].map(&:id))
      end

      it 'sorts by name in the request locale' do
        search('jobs', sort: 'name')
        expect(order_of(mine)).to eq([a, b, c].map(&:id))

        search('jobs', sort: 'name', order: 'desc', locale: 'ja')
        expect(order_of(mine)).to eq([a, c, b].map(&:id))
      end

      it 'sorts by row, keeping order ascending within a row' do
        search('jobs', sort: 'row', order: 'desc')
        expect(order_of(mine)).to eq([a, c, b].map(&:id))
      end

      it 'sorts by first proficiency' do
        search('jobs', sort: 'proficiency', order: 'desc')
        expect(order_of(mine)).to eq([b, c, a].map(&:id))
      end

      it 'falls back to row, order and id for an unknown sort' do
        tied = create_list(:job, 2, row: '1', order: 0)
        search('jobs', sort: 'nonsense')
        expect(order_of(mine + tied)).to eq(tied.map(&:id).sort + [c, b, a].map(&:id))
      end
    end

    it 'pages results' do
      search('jobs', { page: 1 }, 5)
      expect(response.parsed_body['results'].length).to eq(5)
      expect(response.parsed_body['meta']).to eq('count' => Job.count, 'total_pages' => (Job.count / 5.0).ceil,
                                                 'per_page' => 5)
    end
  end

  describe 'POST /api/v1/search/job_skills' do
    it 'returns error without job param' do
      search('job_skills', page: 1)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns not found for an unknown job' do
      search('job_skills', job: SecureRandom.uuid)
      expect(response).to have_http_status(:not_found)
    end

    # Regression: clients send "jp" for Japanese, but the search scope is
    # ja_search. The locale must normalize so it doesn't call a missing
    # jp_search scope (was a 500: NameError undefined method 'jp_search').
    it 'does not error when given a jp locale with a query' do
      base = create(:job)
      job = create(:job, base_job: base)
      create(:job_skill, job: job)
      search('job_skills', job: job.id, locale: 'jp', query: 'skill')
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end

    # Regression: a job with no base_job (e.g. a base job itself) made the query
    # dereference job.base_job.id on nil -> 500 NoMethodError. Both branches.
    it 'does not error for a job without a base_job (empty query)' do
      job = create(:job, base_job: nil)
      create(:job_skill, job: job)
      search('job_skills', job: job.id, locale: 'en', query: '')
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end

    it 'does not error for a job without a base_job (with query)' do
      job = create(:job, base_job: nil)
      create(:job_skill, job: job)
      search('job_skills', job: job.id, locale: 'en', query: 'skill')
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['results']).to be_an(Array)
    end

    context 'with a job, its base job and a sibling' do
      let(:base) { create(:job) }
      let(:job) { create(:job, base_job: base) }
      let(:sibling) { create(:job, base_job: base) }
      let(:stranger) { create(:job) }

      let!(:own) { create(:job_skill, job: job, name_en: 'Zyx own', name_jp: 'ズィクス 自分', color: 0) }
      let!(:own_main) { create(:job_skill, :main_skill, job: job, name_en: 'Zyx main') }
      let!(:other_sub) { create(:job_skill, :sub_skill, job: stranger, name_en: 'Zyx sub', color: 2) }
      let!(:other_plain) { create(:job_skill, job: stranger, name_en: 'Zyx plain') }
      let!(:base_own_base) { create(:job_skill, :base_skill, job: base, name_en: 'Zyx base own') }
      let!(:sibling_base) { create(:job_skill, :base_skill, job: sibling, name_en: 'Zyx base sibling') }
      let!(:sibling_emp) { create(:job_skill, :emp_skill, job: sibling, name_en: 'Zyx emp sibling') }
      let(:everything) { [own, own_main, other_sub, other_plain, base_own_base, sibling_base, sibling_emp] }

      it "lists the job's own skills, subskills, the base job's base skills and siblings' EMP skills" do
        search('job_skills', job: job.id)
        expect(order_of(everything)).to contain_exactly(own.id, other_sub.id, base_own_base.id, sibling_emp.id)
      end

      it "lists siblings' base skills instead of the base job's own when searching" do
        search('job_skills', job: job.id, query: 'Zyx')
        expect(order_of(everything)).to contain_exactly(own.id, other_sub.id, sibling_base.id, sibling_emp.id)
      end

      it 'searches Japanese names in the ja locale' do
        search('job_skills', job: job.id, query: 'ズィクス', locale: 'ja')
        expect(order_of(everything)).to eq([own.id])
      end

      {
        '0' => :own, 2 => :other_sub, 4 => :sibling_emp, 5 => :base_own_base
      }.each do |group, skill|
        it "filters by group #{group}" do
          search('job_skills', job: job.id, filters: { group: group })
          expect(order_of(everything)).to eq([public_send(skill).id])
        end
      end

      it 'ignores an out-of-range group' do
        search('job_skills', job: job.id, filters: { group: 9 })
        expect(order_of(everything)).to contain_exactly(own.id, other_sub.id, base_own_base.id, sibling_emp.id)
      end

      it 'pages results' do
        search('job_skills', { job: job.id, query: 'Zyx' }, 3)
        expect(response.parsed_body['results'].length).to eq(3)
        expect(response.parsed_body['meta']).to eq('count' => 4, 'total_pages' => 2, 'per_page' => 3)
      end
    end
  end

  describe 'POST /api/v1/search/guidebooks' do
    it 'returns guidebooks with results and meta' do
      search('guidebooks', page: 1)
      expect(response).to have_http_status(:ok)

      json = response.parsed_body
      expect(json['results']).to be_an(Array)
      expect(json['meta']).to be_present
    end

    it 'searches English names' do
      book = create(:guidebook, name_en: 'Zyxbook')
      search('guidebooks', query: 'Zyxbook')
      expect(result_ids).to eq([book.id])
    end

    it 'lists every guidebook without a query' do
      search('guidebooks', { query: 'Z' }, 50)
      expect(response.parsed_body['meta']['count']).to eq(Guidebook.count)
    end

    it 'pages results' do
      search('guidebooks', { page: 1 }, 2)
      expect(response.parsed_body['results'].length).to eq(2)
      expect(response.parsed_body['meta']).to eq('count' => Guidebook.count,
                                                 'total_pages' => (Guidebook.count / 2.0).ceil, 'per_page' => 2)
    end
  end
end
