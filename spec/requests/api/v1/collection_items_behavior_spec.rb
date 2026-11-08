# frozen_string_literal: true

require 'rails_helper'

# Behavior the character, weapon and summon collection endpoints share:
# privacy on reads, ownership on writes, index sorting and filtering, batch
# endpoints and imports. Type-specific filters live in the per-type groups
# at the bottom.
RSpec.shared_examples 'a collection item API' do |type, batch_meta_keys:, import_keys:|
  let(:item_type) { type }
  let(:user) { create(:user, language: 'en') }
  let(:other_user) { create(:user) }
  let(:access_token) do
    Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
  end
  let(:headers) do
    { 'Authorization' => "Bearer #{access_token.token}", 'Content-Type' => 'application/json' }
  end
  let(:anonymous_headers) { { 'Content-Type' => 'application/json' } }

  let(:plural) { "#{item_type}s" }
  let(:param_key) { "collection_#{item_type}" }
  let(:foreign_key) { "#{item_type}_id" }
  let(:model) { "Collection#{item_type.to_s.camelize}".constantize }
  let(:write_path) { "/api/v1/collection/#{plural}" }
  let(:forbidden_body) { { 'error' => 'You do not have permission to view this collection' } }

  def read_path(owner, id = nil)
    ["/api/v1/users/#{owner.id}/collection/#{plural}", id].compact.join('/')
  end

  def catalog_item(**attrs)
    create(item_type, **attrs)
  end

  def own(owner, catalog = catalog_item, **attrs)
    create(:"collection_#{item_type}", user: owner, item_type => catalog, **attrs)
  end

  def returned_catalog_ids
    response.parsed_body[plural].map { |item| item[item_type.to_s]['id'] }
  end

  def returned_unowned_ids
    response.parsed_body[plural].map { |item| item['id'] }
  end

  def dated(**attrs)
    catalog_item(flb_date: nil, ulb_date: nil, transcendence_date: nil, **attrs)
  end

  describe 'collection privacy' do
    let(:owner) { create(:user) }
    let!(:owned) { own(owner) }

    it 'shows another user\'s public collection with only their items' do
      own(user)

      get read_path(owner), headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body[plural].pluck('id')).to eq([owned.id])
    end

    it 'shows a crew-only collection to a crewmate' do
      owner.update!(collection_privacy: :crew_only)
      crew = create(:crew)
      create(:crew_membership, crew: crew, user: owner)
      create(:crew_membership, crew: crew, user: user)

      get read_path(owner), headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body[plural].pluck('id')).to eq([owned.id])
    end

    it 'hides a crew-only collection from someone outside the crew' do
      owner.update!(collection_privacy: :crew_only)

      get read_path(owner), headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq(forbidden_body)
    end

    it 'hides a private collection from another signed-in user' do
      owner.update!(collection_privacy: :private_collection)

      get read_path(owner), headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq(forbidden_body)
    end

    it 'hides a single item in a private collection' do
      owner.update!(collection_privacy: :private_collection)

      get read_path(owner, owned.id), headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body).to eq(forbidden_body)
    end

    it 'shows the owner their own private collection' do
      user.update!(collection_privacy: :private_collection)
      mine = own(user)

      get read_path(user), headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body[plural].pluck('id')).to eq([mine.id])
    end

    it 'returns not found for an unknown user' do
      get "/api/v1/users/#{SecureRandom.uuid}/collection/#{plural}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to eq('error' => 'User not found')
    end
  end

  describe 'index sorting' do
    it 'sorts owned items by name' do
      zed = own(user, catalog_item(name_en: 'Zzz SortProbe'))
      abe = own(user, catalog_item(name_en: 'Aaa SortProbe'))

      get read_path(user), params: { search: 'SortProbe', sort: 'name_asc' }, headers: headers
      expect(returned_catalog_ids).to eq([abe.public_send(item_type).id, zed.public_send(item_type).id])

      get read_path(user), params: { search: 'SortProbe', sort: 'name_desc' }, headers: headers
      expect(returned_catalog_ids).to eq([zed.public_send(item_type).id, abe.public_send(item_type).id])
    end

    it 'sorts owned items by release date' do
      old = dated(release_date: 3.years.ago.to_date)
      new = dated(release_date: 1.month.ago.to_date)
      own(user, old)
      own(user, new)

      get read_path(user), params: { sort: 'release_date_asc' }, headers: headers
      expect(returned_catalog_ids).to eq([old.id, new.id])

      get read_path(user), params: { sort: 'release_date_desc' }, headers: headers
      expect(returned_catalog_ids).to eq([new.id, old.id])
    end

    it 'sorts unowned items by name in the viewer\'s language' do
      user.update!(language: 'ja')
      first_ja = catalog_item(name_en: 'Zzz SortProbe', name_jp: 'あ')
      last_ja = catalog_item(name_en: 'Aaa SortProbe', name_jp: 'ん')

      get read_path(user), params: { unowned: true, search: 'SortProbe', sort: 'name_asc' }, headers: headers
      expect(returned_unowned_ids).to eq([first_ja.id, last_ja.id])

      get read_path(user), params: { unowned: true, search: 'SortProbe', sort: 'name_desc' }, headers: headers
      expect(returned_unowned_ids).to eq([last_ja.id, first_ja.id])
    end

    it 'sorts unowned items by element' do
      water = catalog_item(name_en: 'Water SortProbe', element: 4)
      fire = catalog_item(name_en: 'Fire SortProbe', element: 1)

      get read_path(user), params: { unowned: true, search: 'SortProbe', sort: 'element_asc' }, headers: headers
      expect(returned_unowned_ids).to eq([fire.id, water.id])

      get read_path(user), params: { unowned: true, search: 'SortProbe', sort: 'element_desc' }, headers: headers
      expect(returned_unowned_ids).to eq([water.id, fire.id])
    end

    it 'sorts unowned items by release date, newest first by default' do
      old = dated(name_en: 'Old SortProbe', release_date: 3.years.ago.to_date)
      new = dated(name_en: 'New SortProbe', release_date: 1.month.ago.to_date)

      get read_path(user), params: { unowned: true, search: 'SortProbe' }, headers: headers
      expect(returned_unowned_ids).to eq([new.id, old.id])

      get read_path(user), params: { unowned: true, search: 'SortProbe', sort: 'release_date_asc' }, headers: headers
      expect(returned_unowned_ids).to eq([old.id, new.id])

      get read_path(user), params: { unowned: true, search: 'SortProbe', sort: 'release_date_desc' }, headers: headers
      expect(returned_unowned_ids).to eq([new.id, old.id])
    end
  end

  describe 'index filters' do
    it 'treats comma-separated elements as OR on owned items' do
      fire = own(user, catalog_item(element: 1))
      water = own(user, catalog_item(element: 4))
      own(user, catalog_item(element: 3))

      get read_path(user), params: { element: '1,4' }, headers: headers

      expect(response.parsed_body[plural].pluck('id')).to contain_exactly(fire.id, water.id)
    end

    it 'treats comma-separated elements as OR on unowned items' do
      fire = catalog_item(name_en: 'Fire FilterProbe', element: 1)
      water = catalog_item(name_en: 'Water FilterProbe', element: 4)
      catalog_item(name_en: 'Earth FilterProbe', element: 3)

      get read_path(user), params: { unowned: true, search: 'FilterProbe', element: '1,4' }, headers: headers

      expect(returned_unowned_ids).to contain_exactly(fire.id, water.id)
    end

    it 'filters unowned items by rarity' do
      ssr = catalog_item(name_en: 'SSR FilterProbe', rarity: 3)
      catalog_item(name_en: 'SR FilterProbe', rarity: 2)

      get read_path(user), params: { unowned: true, search: 'FilterProbe', rarity: 3 }, headers: headers

      expect(returned_unowned_ids).to eq([ssr.id])
    end

    it 'searches owned items by name' do
      match = own(user, catalog_item(name_en: 'Needle SearchProbe'))
      own(user, catalog_item(name_en: 'Haystack'))

      get read_path(user), params: { search: 'needle' }, headers: headers

      expect(response.parsed_body[plural].pluck('id')).to eq([match.id])
    end
  end

  describe 'create' do
    it 'requires authentication' do
      post write_path, params: { param_key => { foreign_key => catalog_item.id } }.to_json,
                       headers: anonymous_headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'adds the item to the signed-in user\'s collection, ignoring a user_id in the body' do
      catalog = catalog_item
      body = { param_key => { foreign_key => catalog.id, uncap_level: 3, user_id: other_user.id } }

      post write_path, params: body.to_json, headers: headers

      expect(response).to have_http_status(:created)
      record = model.find(response.parsed_body['id'])
      expect(record.user_id).to eq(user.id)
      expect(other_user.public_send(:"collection_#{plural}")).to be_empty
    end
  end

  describe 'update' do
    let!(:record) { own(user, uncap_level: 3) }

    it 'requires authentication' do
      put "#{write_path}/#{record.id}", params: { param_key => { uncap_level: 4 } }.to_json,
                                        headers: anonymous_headers

      expect(response).to have_http_status(:unauthorized)
      expect(record.reload.uncap_level).to eq(3)
    end

    it 'cannot move the item to another user' do
      put "#{write_path}/#{record.id}",
          params: { param_key => { uncap_level: 4, user_id: other_user.id } }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(record.reload).to have_attributes(user_id: user.id, uncap_level: 4)
    end
  end

  describe 'destroy' do
    it 'requires authentication' do
      record = own(user)

      delete "#{write_path}/#{record.id}", headers: anonymous_headers

      expect(response).to have_http_status(:unauthorized)
      expect(model.exists?(record.id)).to be true
    end
  end

  describe 'batch' do
    it 'requires authentication' do
      post "#{write_path}/batch", params: { "collection_#{plural}" => [] }.to_json, headers: anonymous_headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates the items for the signed-in user' do
      first = catalog_item
      second = catalog_item
      items = [{ foreign_key => first.id, uncap_level: 3 }, { foreign_key => second.id, uncap_level: 3 }]

      post "#{write_path}/batch", params: { "collection_#{plural}" => items }.to_json, headers: headers

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body['meta'].keys).to eq(batch_meta_keys)
      expect(body['meta']['created']).to eq(2)
      expect(body[plural].map { |item| item[item_type.to_s]['id'] }).to contain_exactly(first.id, second.id)
      expect(user.public_send(:"collection_#{plural}").count).to eq(2)
    end

    it 'reports items that fail with multi-status' do
      items = [{ foreign_key => catalog_item.id, uncap_level: 3 }, { foreign_key => nil, uncap_level: 3 }]

      post "#{write_path}/batch", params: { "collection_#{plural}" => items }.to_json, headers: headers

      expect(response).to have_http_status(:multi_status)
      meta = response.parsed_body['meta']
      expect(meta['created']).to eq(1)
      expect(meta['errors'].length).to eq(1)
      expect(meta['errors'].first.keys).to eq(['index', foreign_key, 'error'])
      expect(meta['errors'].first['index']).to eq(1)
    end

    it 'returns an empty result when no items are sent' do
      post "#{write_path}/batch", params: {}.to_json, headers: headers

      expect(response).to have_http_status(:created)
      expect(response.parsed_body[plural]).to eq([])
      expect(response.parsed_body['meta']['created']).to eq(0)
    end
  end

  describe 'batch_destroy' do
    it 'deletes only the signed-in user\'s items' do
      mine = own(user)
      theirs = own(other_user)

      delete "#{write_path}/batch_destroy", params: { ids: [mine.id, theirs.id] }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('meta' => { 'deleted' => 1 })
      expect(model.exists?(mine.id)).to be false
      expect(model.exists?(theirs.id)).to be true
    end

    it 'requires authentication' do
      mine = own(user)

      delete "#{write_path}/batch_destroy", params: { ids: [mine.id] }.to_json, headers: anonymous_headers

      expect(response).to have_http_status(:unauthorized)
      expect(model.exists?(mine.id)).to be true
    end
  end

  describe 'import' do
    it 'requires authentication' do
      post "#{write_path}/import", params: { data: { 'list' => [] } }.to_json, headers: anonymous_headers

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns bad request without data' do
      post "#{write_path}/import", params: {}.to_json, headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'No data provided')
    end

    it 'reports an import with nothing to import' do
      post "#{write_path}/import", params: { data: { 'list' => [] } }.to_json, headers: headers

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body.keys).to eq(import_keys)
      expect(response.parsed_body['success']).to be false
    end
  end

  describe 'check_updates' do
    it 'returns bad request without data' do
      post "#{write_path}/check_updates", params: {}.to_json, headers: headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'No data provided')
    end
  end
end

RSpec.shared_examples 'a full-inventory sync API' do |item_type|
  let(:plural) { "#{item_type}s" }
  let(:sync_user) { create(:user) }
  let(:sync_headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: sync_user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def game_item(game_id, granblue_id)
    {
      'param' => { 'id' => game_id, 'image_id' => granblue_id, 'evolution' => 3, 'phase' => 0 },
      'master' => { 'id' => granblue_id }
    }
  end

  describe 'preview_sync' do
    it 'lists the signed-in user\'s items missing from the import' do
      kept = create(:"collection_#{item_type}", user: sync_user, game_id: 'keep-1')
      gone = create(:"collection_#{item_type}", user: sync_user, game_id: 'gone-1', uncap_level: 4)
      create(:"collection_#{item_type}", user: create(:user), game_id: 'theirs-1')
      catalog = kept.public_send(item_type)

      post "/api/v1/collection/#{plural}/preview_sync",
           params: { data: { 'list' => [game_item('keep-1', catalog.granblue_id)] } }.to_json,
           headers: sync_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'will_delete' => [{
          'id' => gone.id,
          'game_id' => 'gone-1',
          'name' => gone.public_send(item_type).name_en,
          'granblue_id' => gone.public_send(item_type).granblue_id,
          'uncap_level' => 4,
          'transcendence_step' => 0
        }],
        'count' => 1
      )
    end

    it 'returns bad request without data' do
      post "/api/v1/collection/#{plural}/preview_sync", params: {}.to_json, headers: sync_headers

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'No data provided')
    end

    it 'requires authentication' do
      post "/api/v1/collection/#{plural}/preview_sync", params: { data: { 'list' => [] } }.to_json,
                                                        headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end

RSpec.describe 'Collection item endpoints', type: :request do
  let(:user) { create(:user, language: 'en') }
  let(:headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  describe 'characters' do
    it_behaves_like 'a collection item API', :character,
                    batch_meta_keys: %w[created skipped skipped_items errors],
                    import_keys: %w[success created updated skipped errors]

    it 'skips characters already in the collection during a batch' do
      owned = create(:character)
      fresh = create(:character)
      create(:collection_character, user: user, character: owned)
      items = [{ character_id: owned.id, uncap_level: 3 }, { character_id: fresh.id, uncap_level: 3 }]

      post '/api/v1/collection/characters/batch', params: { collection_characters: items }.to_json, headers: headers

      expect(response).to have_http_status(:created)
      meta = response.parsed_body['meta']
      expect(meta).to include('created' => 1, 'skipped' => 1, 'errors' => [])
      expect(meta['skipped_items']).to eq([{ 'index' => 0, 'character_id' => owned.id, 'reason' => 'already_exists' }])
    end

    # Sentry HENSEI-API-N: the owned check ran once per item. What's left is the
    # model's uniqueness validation, once per saved character.
    it 'checks which batch characters are owned in one query' do
      items = create_list(:character, 4).map { |character| { character_id: character.id, uncap_level: 3 } }
      owned_checks = []
      sub = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        sql = payload[:sql]
        owned_checks << sql if sql.start_with?('SELECT') && sql.include?('FROM "collection_characters"')
      end

      post '/api/v1/collection/characters/batch', params: { collection_characters: items }.to_json, headers: headers

      ActiveSupport::Notifications.unsubscribe(sub)
      expect(response).to have_http_status(:created)
      expect(owned_checks.size).to eq(1 + items.size)
    end

    it 'skips a character listed twice in one batch' do
      character = create(:character)
      items = [{ character_id: character.id, uncap_level: 3 }, { character_id: character.id, uncap_level: 4 }]

      post '/api/v1/collection/characters/batch', params: { collection_characters: items }.to_json, headers: headers

      expect(response.parsed_body['meta']).to include('created' => 1, 'skipped' => 1, 'errors' => [])
    end

    it 'imports characters and updates existing ones only when asked' do
      character = create(:character)
      create(:collection_character, user: user, character: character, uncap_level: 3)
      data = { 'list' => [{ 'param' => { 'id' => '1', 'evolution' => 4, 'phase' => 0 },
                            'master' => { 'id' => character.granblue_id } }] }

      post '/api/v1/collection/characters/import', params: { data: data }.to_json, headers: headers
      expect(response.parsed_body).to include('created' => 0, 'updated' => 0, 'skipped' => 1)

      post '/api/v1/collection/characters/import', params: { data: data, update_existing: true }.to_json,
                                                   headers: headers
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('success' => true, 'updated' => 1)
    end

    it 'filters by race, proficiency and gender on owned and unowned characters' do
      both = create(:character, name_en: 'Both FilterProbe', race1: 1, race2: 2, proficiency1: 3, gender: 1)
      second = create(:character, name_en: 'Second FilterProbe', race1: 2, proficiency1: 1, proficiency2: 3, gender: 1)
      create(:character, name_en: 'Neither FilterProbe', race1: 4, proficiency1: 5, gender: 2)
      owned = [both, second].map { |c| create(:collection_character, user: user, character: c).id }
      filters = { search: 'FilterProbe', race: 2, proficiency: 3, gender: 1 }

      get "/api/v1/users/#{user.id}/collection/characters", params: filters, headers: headers
      expect(response.parsed_body['characters'].pluck('id')).to match_array(owned)

      get "/api/v1/users/#{create(:user).id}/collection/characters", params: filters.merge(unowned: true),
                                                                     headers: headers
      expect(response.parsed_body['characters'].pluck('id')).to contain_exactly(both.id, second.id)
    end

    it 'sorts unowned characters by their main proficiency' do
      spear = create(:character, name_en: 'Spear SortProbe', proficiency1: 4, proficiency2: 1)
      dagger = create(:character, name_en: 'Dagger SortProbe', proficiency1: 2, proficiency2: 9)
      path = "/api/v1/users/#{user.id}/collection/characters"

      get path, params: { unowned: true, search: 'SortProbe', sort: 'proficiency_asc' }, headers: headers
      expect(response.parsed_body['characters'].pluck('id')).to eq([dagger.id, spear.id])

      get path, params: { unowned: true, search: 'SortProbe', sort: 'proficiency_desc' }, headers: headers
      expect(response.parsed_body['characters'].pluck('id')).to eq([spear.id, dagger.id])
    end
  end

  describe 'weapons' do
    it_behaves_like 'a collection item API', :weapon,
                    batch_meta_keys: %w[created errors],
                    import_keys: %w[success created updated skipped errors reconciliation]
    it_behaves_like 'a full-inventory sync API', :weapon

    it 'filters by proficiency and series on owned and unowned weapons' do
      series = create(:weapon_series)
      match = create(:weapon, name_en: 'Match FilterProbe', proficiency: 3, weapon_series: series)
      create(:weapon, name_en: 'Wrong proficiency FilterProbe', proficiency: 4, weapon_series: series)
      create(:weapon, name_en: 'Wrong series FilterProbe', proficiency: 3)
      owned = Weapon.where('name_en LIKE ?', '%FilterProbe').map { |w| create(:collection_weapon, user: user, weapon: w) }
      filters = { search: 'FilterProbe', proficiency: 3, series: series.id }

      get "/api/v1/users/#{user.id}/collection/weapons", params: filters, headers: headers
      expect(response.parsed_body['weapons'].pluck('id')).to eq([owned.find { |cw| cw.weapon_id == match.id }.id])

      get "/api/v1/users/#{create(:user).id}/collection/weapons", params: filters.merge(unowned: true), headers: headers
      expect(response.parsed_body['weapons'].pluck('id')).to eq([match.id])
    end

    it 'sorts unowned weapons by proficiency' do
      spear = create(:weapon, name_en: 'Spear SortProbe', proficiency: 4)
      dagger = create(:weapon, name_en: 'Dagger SortProbe', proficiency: 2)
      path = "/api/v1/users/#{user.id}/collection/weapons"

      get path, params: { unowned: true, search: 'SortProbe', sort: 'proficiency_asc' }, headers: headers
      expect(response.parsed_body['weapons'].pluck('id')).to eq([dagger.id, spear.id])

      get path, params: { unowned: true, search: 'SortProbe', sort: 'proficiency_desc' }, headers: headers
      expect(response.parsed_body['weapons'].pluck('id')).to eq([spear.id, dagger.id])
    end
  end

  describe 'summons' do
    it_behaves_like 'a collection item API', :summon,
                    batch_meta_keys: %w[created errors],
                    import_keys: %w[success created updated skipped errors reconciliation]
    it_behaves_like 'a full-inventory sync API', :summon

    it 'filters by series on owned and unowned summons' do
      series = create(:summon_series)
      match = create(:summon, name_en: 'Match FilterProbe', summon_series: series)
      other = create(:summon, name_en: 'Other FilterProbe')
      owned = create(:collection_summon, user: user, summon: match)
      create(:collection_summon, user: user, summon: other)

      get "/api/v1/users/#{user.id}/collection/summons", params: { series: series.id }, headers: headers
      expect(response.parsed_body['summons'].pluck('id')).to eq([owned.id])

      get "/api/v1/users/#{create(:user).id}/collection/summons",
          params: { unowned: true, search: 'FilterProbe', series: series.id }, headers: headers
      expect(response.parsed_body['summons'].pluck('id')).to eq([match.id])
    end

    it 'filters unowned summons by support eligibility' do
      eligible = create(:summon, name_en: 'Eligible FilterProbe', support_eligible: true)
      create(:summon, name_en: 'Ineligible FilterProbe', support_eligible: false)

      get "/api/v1/users/#{user.id}/collection/summons",
          params: { unowned: true, search: 'FilterProbe', support_eligible: 'true' }, headers: headers

      expect(response.parsed_body['summons'].pluck('id')).to eq([eligible.id])
    end

    it 'falls back to newest first for a proficiency sort on unowned summons' do
      old = create(:summon, name_en: 'Old SortProbe', release_date: 3.years.ago, flb_date: nil)
      new = create(:summon, name_en: 'New SortProbe', release_date: 1.month.ago, flb_date: nil)

      get "/api/v1/users/#{user.id}/collection/summons",
          params: { unowned: true, search: 'SortProbe', sort: 'proficiency_asc' }, headers: headers

      expect(response.parsed_body['summons'].pluck('id')).to eq([new.id, old.id])
    end
  end
end
