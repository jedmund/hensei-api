# frozen_string_literal: true

require 'rails_helper'

# The collection imports the browser extension sends. Bodies follow
# hensei-extractor's uploadCollectionData and uploadCharacterStats: the game's
# list items under data.list, the sync flags, and the game filter as
# element_ids / proficiency_ids (null when the game view has no filter).
# Items come from spec/fixtures/collection_import, lifted from real game
# responses.
RSpec.describe 'Collection imports from the extension', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:headers) do
    token = Doorkeeper::AccessToken.create!(resource_owner_id: user.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def fixture(name)
    JSON.parse(Rails.root.join('spec/fixtures/collection_import', "#{name}.json").read)
  end

  def extension_body(data, update_existing: false, is_full_inventory: false, reconcile_deletions: false,
                     filter: nil, **extra)
    { data: data, update_existing: update_existing, is_full_inventory: is_full_inventory,
      reconcile_deletions: reconcile_deletions, filter: filter, **extra }
  end

  # The test database holds canonical seed rows, some with these ids.
  def catalog(factory, *traits, granblue_id:, **attrs)
    model = factory.to_s.camelize.constantize
    existing = model.find_by(granblue_id: granblue_id)
    return create(factory, *traits, granblue_id: granblue_id, **attrs) unless existing

    existing.update!(attributes_for(factory, *traits).slice(:flb, :ulb, :transcendence).merge(attrs))
    existing
  end

  def awakening(slug, object_type)
    Awakening.find_by(slug: slug, object_type: object_type) ||
      create(:awakening, :"for_#{object_type.downcase}", slug: slug)
  end

  def raw(record, attribute)
    record.read_attribute_before_type_cast(attribute)
  end

  def import(type, body, request_headers = headers)
    post "/api/v1/collection/#{type}/import", params: body.to_json, headers: request_headers
  end

  describe 'POST /collection/weapons/import' do
    let!(:torch) { catalog(:weapon, granblue_id: '1040422700', element: 2, proficiency: 6) }
    let!(:ygg) { catalog(:weapon, :transcendable, granblue_id: '1040310600', element: 4, proficiency: 1) }
    let!(:claw) do
      catalog(:weapon, granblue_id: '1040213900', element: 6, proficiency: 6,
                       weapon_series: create(:weapon_series, :with_ax_skills))
    end
    let!(:special_awakening) { awakening('weapon-special', 'Weapon') }
    let!(:ax_atk) { create(:weapon_stat_modifier, :ax_atk) }
    let!(:ax_ca_dmg) { create(:weapon_stat_modifier, :ax_ca_dmg) }

    it 'creates every known weapon and reports the unknown one' do
      import('weapons', extension_body(fixture('weapons')))

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to eq(
        'success' => false, 'created' => 3, 'updated' => 0, 'skipped' => 0,
        'errors' => [{ 'game_id' => 4_585_965_620, 'granblue_id' => '1049999900', 'error' => 'Weapon not found' }],
        'reconciliation' => nil
      )
    end

    it 'maps uncap, transcendence, awakening and AX from the game fields' do
      import('weapons', extension_body(fixture('weapons')))

      weapons = user.collection_weapons.index_by(&:game_id)
      expect(weapons.keys).to contain_exactly('4585965586', '4585965601', '4585965617')
      expect(weapons['4585965586']).to have_attributes(weapon_id: torch.id, uncap_level: 4, transcendence_step: 0,
                                                       awakening_id: nil, element: nil)
      expect(weapons['4585965601']).to have_attributes(weapon_id: ygg.id, uncap_level: 6, transcendence_step: 3,
                                                       awakening_id: special_awakening.id, awakening_level: 7)
      expect(weapons['4585965617']).to have_attributes(weapon_id: claw.id, uncap_level: 5,
                                                       ax_modifier1_id: ax_atk.id, ax_strength1: 2.5,
                                                       ax_modifier2_id: ax_ca_dmg.id, ax_strength2: 4.0,
                                                       skill_level: 15)
    end

    it 'skips weapons it already has, and updates them only when asked' do
      import('weapons', extension_body(fixture('weapons')))
      data = fixture('weapons')
      data['list'][0]['param']['evolution'] = '5'

      import('weapons', extension_body(data))
      expect(response.parsed_body).to include('created' => 0, 'updated' => 0, 'skipped' => 3)
      expect(user.collection_weapons.find_by(game_id: '4585965586').uncap_level).to eq(4)

      import('weapons', extension_body(data, update_existing: true))
      expect(response.parsed_body).to include('created' => 0, 'updated' => 3, 'skipped' => 0)
      expect(user.collection_weapons.find_by(game_id: '4585965586').uncap_level).to eq(5)
      expect(user.collection_weapons.count).to eq(3)
    end

    it 'deletes weapons missing from a full inventory, inside the game filter only' do
      linked = create(:collection_weapon, user: user, weapon: torch, game_id: 'sold-fire')
      grid_weapon = create(:grid_weapon, weapon: torch, collection_weapon: linked)
      kept_outside_filter = create(:collection_weapon, user: user, weapon: ygg, game_id: 'sold-earth')
      kept_without_game_id = create(:collection_weapon, user: user, weapon: torch, game_id: nil)
      theirs = create(:collection_weapon, user: other_user, weapon: torch, game_id: 'theirs')

      import('weapons', extension_body(fixture('weapons'), is_full_inventory: true, reconcile_deletions: true,
                                                           filter: { element_ids: [2], proficiency_ids: nil }))

      expect(response.parsed_body['reconciliation']).to eq('deleted' => 1, 'orphaned_grid_items' => [grid_weapon.id])
      expect(CollectionWeapon.exists?(linked.id)).to be false
      expect(grid_weapon.reload.orphaned).to be true
      expect(CollectionWeapon.where(id: [kept_outside_filter, kept_without_game_id, theirs]).count).to eq(3)
    end

    it 'leaves the collection alone unless both sync flags are set' do
      stale = create(:collection_weapon, user: user, weapon: torch, game_id: 'stale')

      import('weapons', extension_body(fixture('weapons'), reconcile_deletions: true))
      expect(response.parsed_body['reconciliation']).to be_nil

      import('weapons', extension_body(fixture('weapons'), is_full_inventory: true))
      expect(response.parsed_body['reconciliation']).to be_nil
      expect(CollectionWeapon.exists?(stale.id)).to be true
    end

    it 'adopts or skips a hand-added copy as the conflict resolutions say' do
      hand_added_torch = create(:collection_weapon, user: user, weapon: torch, game_id: nil, uncap_level: 3)
      hand_added_claw = create(:collection_weapon, user: user, weapon: claw, game_id: nil)

      import('weapons', extension_body(fixture('weapons'),
                                       conflict_resolutions: { '4585965586' => 'import', '4585965617' => 'skip' }))

      expect(response.parsed_body).to include('created' => 1, 'updated' => 1, 'skipped' => 1)
      expect(hand_added_torch.reload).to have_attributes(game_id: '4585965586', uncap_level: 4)
      expect(hand_added_claw.reload.game_id).to be_nil
    end

    it 'imports into the signed-in user\'s collection, whatever user_id the body names' do
      import('weapons', extension_body(fixture('weapons'), user_id: other_user.id))

      expect(user.collection_weapons.count).to eq(3)
      expect(other_user.collection_weapons.count).to eq(0)
    end

    it 'requires a signed-in user' do
      import('weapons', extension_body(fixture('weapons')), { 'Content-Type' => 'application/json' })

      expect(response).to have_http_status(:unauthorized)
      expect(CollectionWeapon.count).to eq(0)
    end
  end

  describe 'POST /collection/summons/import' do
    let!(:agni) { catalog(:summon, :transcendable, granblue_id: '2040094000', element: 2) }
    let!(:bahamut) { catalog(:summon, granblue_id: '2040003000', element: 5, flb: true, ulb: true) }

    it 'creates the known summons from suffixed image ids and reports the unknown one' do
      import('summons', extension_body(fixture('summons')))

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to eq(
        'success' => false, 'created' => 2, 'updated' => 0, 'skipped' => 0,
        'errors' => [{ 'game_id' => '591430971', 'granblue_id' => '2049999900', 'error' => 'Summon not found' }],
        'reconciliation' => nil
      )
      summons = user.collection_summons.index_by(&:game_id)
      expect(summons['591430969']).to have_attributes(summon_id: agni.id, uncap_level: 6, transcendence_step: 4)
      expect(summons['591430970']).to have_attributes(summon_id: bahamut.id, uncap_level: 5, transcendence_step: 0)
    end

    it 'skips, then updates, summons it already has' do
      import('summons', extension_body(fixture('summons')))
      import('summons', extension_body(fixture('summons')))
      expect(response.parsed_body).to include('created' => 0, 'updated' => 0, 'skipped' => 2)

      import('summons', extension_body(fixture('summons'), update_existing: true))
      expect(response.parsed_body).to include('created' => 0, 'updated' => 2, 'skipped' => 0)
    end

    it 'deletes summons missing from a full inventory, inside the element filter only' do
      linked = create(:collection_summon, user: user, summon: agni, game_id: 'sold-fire')
      grid_summon = create(:grid_summon, summon: agni, collection_summon: linked)
      kept = create(:collection_summon, user: user, summon: bahamut, game_id: 'sold-dark')

      import('summons', extension_body(fixture('summons'), is_full_inventory: true, reconcile_deletions: true,
                                                           filter: { element_ids: [2], proficiency_ids: [1] }))

      expect(response.parsed_body['reconciliation']).to eq('deleted' => 1, 'orphaned_grid_items' => [grid_summon.id])
      expect(CollectionSummon.exists?(linked.id)).to be false
      expect(CollectionSummon.exists?(kept.id)).to be true
    end

    it 'adopts or skips a hand-added copy as the conflict resolutions say' do
      hand_added = create(:collection_summon, user: user, summon: bahamut, game_id: nil, uncap_level: 3)

      import('summons', extension_body(fixture('summons'),
                                       conflict_resolutions: { '591430970' => 'import', '591430969' => 'skip' }))

      expect(response.parsed_body).to include('created' => 0, 'updated' => 1, 'skipped' => 1)
      expect(hand_added.reload).to have_attributes(game_id: '591430970', uncap_level: 5)
    end
  end

  describe 'POST /collection/characters/import' do
    let!(:balanced) { awakening('character-balanced', 'Character') }
    let!(:attack) { awakening('character-atk', 'Character') }
    let!(:multiattack) { awakening('character-multi', 'Character') }
    let!(:percival) { catalog(:character, granblue_id: '3040425000', flb: true) }
    let!(:siegfried) { catalog(:character, :transcendable, granblue_id: '3040036000') }

    it 'creates the known characters from the collection list and reports the unknown one' do
      import('characters', extension_body(fixture('characters')))

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to eq(
        'success' => false, 'created' => 2, 'updated' => 0, 'skipped' => 0,
        'errors' => [{ 'game_id' => 205_376_861, 'granblue_id' => '3049999900', 'error' => 'Character not found' }]
      )
      characters = user.collection_characters.index_by(&:character_id)
      expect(characters[percival.id]).to have_attributes(uncap_level: 4, transcendence_step: 0,
                                                         awakening_id: balanced.id, awakening_level: 4,
                                                         perpetuity: true)
      expect(characters[siegfried.id]).to have_attributes(uncap_level: 6, transcendence_step: 3,
                                                          awakening_level: 10, perpetuity: false)
    end

    it 'skips characters already owned, naming them by character id' do
      create(:collection_character, user: user, character: percival)

      import('characters', extension_body(fixture('characters')))

      expect(response.parsed_body).to include('created' => 1, 'skipped' => 1)
    end

    it 'updates owned characters from the stats the extension reads off the character pages' do
      import('characters', extension_body(fixture('characters')))

      import('characters', { data: fixture('character_stats'), update_existing: true })

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to eq(
        'success' => false, 'created' => 0, 'updated' => 2, 'skipped' => 0,
        'errors' => [{ 'granblue_id' => '3049999900', 'error' => 'Character not found' }]
      )
      characters = user.collection_characters.index_by(&:character_id)
      expect(characters[percival.id]).to have_attributes(
        uncap_level: 5, transcendence_step: 0, awakening_id: attack.id, awakening_level: 7, perpetuity: true,
        ring1: { 'modifier' => 1, 'strength' => 1500 }, ring2: { 'modifier' => 2, 'strength' => 750 },
        earring: { 'modifier' => 3, 'strength' => 9 }
      )
      expect(characters[siegfried.id]).to have_attributes(uncap_level: 6, transcendence_step: 5,
                                                          awakening_id: multiattack.id, awakening_level: 10)
    end

    it 'creates characters from stats when they are not owned yet' do
      import('characters', { data: fixture('character_stats'), update_existing: true })

      expect(response.parsed_body).to include('created' => 2, 'updated' => 0)
    end
  end

  describe 'POST /collection/artifacts/import' do
    let!(:bangle) { catalog(:artifact, granblue_id: '301070101', proficiency: :melee) }
    let!(:fengtooth) { catalog(:artifact, :quirk, granblue_id: '401110401') }
    let!(:dodge) do
      create(:artifact_skill, :group_i, modifier: 11, name_en: 'Dodge Rate', name_jp: '回避率',
                                        base_values: [4.4, 4.8, 5.2, 5.6, 6.0], score_category: nil)
    end

    before do
      create(:artifact_skill, :group_i, modifier: 2, name_en: 'HP', name_jp: 'HP', base_values: [660, 720, 780, 840, 900])
      create(:artifact_skill, :group_i, modifier: 5, name_en: 'Elemental ATK', name_jp: '自属性攻撃力',
                                        base_values: [8.8, 9.6, 10.4, 11.2, 12.0])
      create(:artifact_skill, :group_ii, modifier: 2, name_en: 'Skill DMG Cap', name_jp: 'アビダメ上限',
                                         base_values: [8.8, 9.6, 10.4, 11.2, 12.0])
      create(:artifact_skill, :group_ii, modifier: 8, name_en: 'C.A. DMG cap boost tradeoff', name_jp: '奥義ダメ上限UP',
                                         base_values: [13.2, 14.4, 15.6, 16.8, 18.0])
      create(:artifact_skill, :group_iii, modifier: 5, name_en: 'Switch amplified', name_jp: 'バトル登場時',
                                          base_values: [3, 6, 9, 12, 15])
      create(:artifact_skill, :group_iii, modifier: 25, name_en: 'Armored', name_jp: 'ブロック効果',
                                          base_values: [5, 10, 15, 20, 25])
      ArtifactSkill.clear_cache!
    end

    after { ArtifactSkill.clear_cache! }

    it 'creates the known artifacts with skills, scores, element and proficiency' do
      import('artifacts', extension_body(fixture('artifacts')))

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to eq(
        'success' => false, 'created' => 2, 'updated' => 0, 'skipped' => 0,
        'errors' => [{ 'game_id' => 8_138_022, 'artifact_id' => 399_999_999, 'error' => 'Artifact not found' }],
        'reconciliation' => nil
      )
      artifacts = user.collection_artifacts.index_by(&:game_id)
      expect(artifacts['8138020']).to have_attributes(
        artifact_id: bangle.id, proficiency: nil, level: 5,
        skill1: { 'modifier' => 11, 'quality' => 1, 'level' => 3 },
        skill2: { 'modifier' => 2, 'quality' => 5, 'level' => 2 },
        skill4: { 'modifier' => 5, 'quality' => 3, 'level' => 1 },
        attack_score: 120, defense_score: 80, special_score: 40, total_score: 240
      )
      expect(raw(artifacts['8138020'], :element)).to eq(5)
      expect(artifacts['8138021']).to have_attributes(artifact_id: fengtooth.id, skill1: {}, skill4: {})
      expect([raw(artifacts['8138021'], :element), raw(artifacts['8138021'], :proficiency)]).to eq([2, 2])
      expect(dodge.reload.score_category).to eq(2)
    end

    it 'skips, then updates, artifacts it already has' do
      import('artifacts', extension_body(fixture('artifacts')))
      import('artifacts', extension_body(fixture('artifacts')))
      expect(response.parsed_body).to include('created' => 0, 'updated' => 0, 'skipped' => 2)

      import('artifacts', extension_body(fixture('artifacts'), update_existing: true))
      expect(response.parsed_body).to include('created' => 0, 'updated' => 2, 'skipped' => 0)
    end

    it 'deletes artifacts missing from a full inventory, inside the element filter only' do
      gone = create(:collection_artifact, user: user, artifact: bangle, game_id: 'sold-light', element: 6)
      kept = create(:collection_artifact, user: user, artifact: bangle, game_id: 'sold-fire', element: 2)
      theirs = create(:collection_artifact, user: other_user, artifact: bangle, game_id: 'theirs', element: 6)

      import('artifacts', extension_body(fixture('artifacts'), is_full_inventory: true, reconcile_deletions: true,
                                                               filter: { element_ids: [6] }))

      expect(response.parsed_body['reconciliation']).to eq('deleted' => 1, 'orphaned_grid_items' => [])
      expect(CollectionArtifact.exists?(gone.id)).to be false
      expect(CollectionArtifact.where(id: [kept, theirs]).count).to eq(2)
    end

    it 'previews the deletions a full sync would make' do
      gone = create(:collection_artifact, user: user, artifact: bangle, game_id: 'sold', element: 6, level: 3)
      create(:collection_artifact, user: other_user, artifact: bangle, game_id: 'theirs')

      post '/api/v1/collection/artifacts/preview_sync', params: { data: fixture('artifacts'), filter: nil }.to_json,
                                                        headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(
        'will_delete' => [{ 'id' => gone.id, 'game_id' => 'sold', 'name' => bangle.name_en,
                            'granblue_id' => '301070101', 'element' => 'dark', 'level' => 3 }],
        'count' => 1
      )
    end

    it 'requires a signed-in user' do
      import('artifacts', extension_body(fixture('artifacts')), { 'Content-Type' => 'application/json' })

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns bad request without data' do
      import('artifacts', { update_existing: false })

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to eq('error' => 'No data provided')
    end
  end

  describe 'malformed data' do
    before { catalog(:weapon, granblue_id: '1040422700') }

    it 'reports a list that is not an array as empty' do
      import('weapons', extension_body({ 'list' => { '0' => fixture('weapons')['list'][0] } }))

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to eq(
        'success' => false, 'created' => 0, 'updated' => 0, 'skipped' => 0,
        'errors' => ['No weapon items found in data'], 'reconciliation' => nil
      )
    end

    it 'reports items that are not objects without failing the rest' do
      import('weapons', extension_body({ 'list' => ['junk', fixture('weapons')['list'][0]] }))

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to eq(
        'success' => false, 'created' => 1, 'updated' => 0, 'skipped' => 0,
        'errors' => [{ 'game_id' => nil, 'granblue_id' => nil, 'error' => 'Weapon not found' }],
        'reconciliation' => nil
      )
    end
  end
end
