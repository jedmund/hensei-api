# frozen_string_literal: true

require 'rails_helper'

# The actions every grid controller (weapons, characters, summons) offers:
# moving and swapping slots, uncapping, removing, and syncing with the linked
# collection item. Each one runs against the party the row really belongs to.
RSpec.describe 'Grid shared actions', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:party) { create(:party, user: user) }
  let(:anonymous_party) { create(:party, user: nil, edit_key: 'test-edit-key') }
  let(:headers) { headers_for(user) }
  let(:other_headers) { headers_for(other_user) }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  def headers_for(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def edit_key_headers(key)
    { 'X-Edit-Key' => key, 'Content-Type' => 'application/json' }
  end

  # Renders a row the way the API should, as parsed JSON.
  def rendered(record, view)
    JSON.parse(blueprint.render(record, view: view))
  end

  shared_examples 'shared grid actions' do |type:, view:, slots:, invalid_position:|
    let(:path) { "grid_#{type}s" }
    let(:root) { "grid_#{type}" }
    let(:param_key) { type }
    let(:blueprint) { "Api::V1::Grid#{type.to_s.capitalize}Blueprint".constantize }
    let(:first_slot) { slots[0] }
    let(:second_slot) { slots[1] }
    let(:free_slot) { slots[2] }

    let!(:first_row) { create(:"grid_#{type}", party: party, position: first_slot) }
    let!(:second_row) { create(:"grid_#{type}", party: party, position: second_slot) }

    describe 'PUT /parties/:party_id/grid_*/:id/position' do
      def move(row, position, party_id: party.id, with: headers)
        put "/api/v1/parties/#{party_id}/#{path}/#{row.id}/position",
            params: { position: position }.to_json, headers: with
      end

      it 'moves the row and returns the party with the moved row' do
        move(first_row, free_slot)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.keys).to start_with('party', root)
        expect(body['party']['id']).to eq(party.id)
        expect(body[root]).to eq(rendered(first_row.reload, view))
        expect(first_row.position).to eq(free_slot)
      end

      it 'refuses an occupied slot' do
        move(first_row, second_slot)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Position #{second_slot} is already occupied")
        expect(first_row.reload.position).to eq(first_slot)
      end

      it 'refuses a slot outside the grid' do
        move(first_row, invalid_position)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("Invalid position #{invalid_position} for #{type}")
        expect(first_row.reload.position).to eq(first_slot)
      end

      it "refuses someone else's party" do
        move(first_row, free_slot, with: other_headers)

        expect(response).to have_http_status(:unauthorized)
        expect(first_row.reload.position).to eq(first_slot)
      end

      it 'refuses a route through another party' do
        other_party = create(:party, user: user)
        move(first_row, free_slot, party_id: other_party.id)

        expect(response).to have_http_status(:not_found)
        expect(first_row.reload.position).to eq(first_slot)
      end

      context 'with an anonymous party' do
        let!(:anon_row) { create(:"grid_#{type}", party: anonymous_party, position: first_slot) }

        it 'moves with the right edit key' do
          move(anon_row, free_slot, party_id: anonymous_party.id, with: edit_key_headers('test-edit-key'))

          expect(response).to have_http_status(:ok)
          expect(anon_row.reload.position).to eq(free_slot)
        end

        it 'refuses a wrong edit key' do
          move(anon_row, free_slot, party_id: anonymous_party.id, with: edit_key_headers('wrong-key'))

          expect(response).to have_http_status(:unauthorized)
          expect(anon_row.reload.position).to eq(first_slot)
        end

        it 'refuses a request without an edit key' do
          move(anon_row, free_slot, party_id: anonymous_party.id, with: json_headers)

          expect(response).to have_http_status(:unauthorized)
          expect(anon_row.reload.position).to eq(first_slot)
        end
      end
    end

    describe 'POST /parties/:party_id/grid_*/swap' do
      def swap(source, target, party_id: party.id, with: headers)
        post "/api/v1/parties/#{party_id}/#{path}/swap",
             params: { source_id: source.id, target_id: target.id }.to_json, headers: with
      end

      it 'swaps the two rows and returns both' do
        swap(first_row, second_row)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.keys).to eq(%w[party swapped])
        expect(body['party']['id']).to eq(party.id)
        expect(body['swapped']['source']).to eq(rendered(first_row.reload, view))
        expect(body['swapped']['target']).to eq(rendered(second_row.reload, view))
        expect(first_row.position).to eq(second_slot)
        expect(second_row.position).to eq(first_slot)
      end

      it 'refuses a row from another party, even one the user owns' do
        foreign = create(:"grid_#{type}", party: create(:party, user: user), position: free_slot)
        swap(first_row, foreign)

        expect(response).to have_http_status(:not_found)
        expect(first_row.reload.position).to eq(first_slot)
        expect(foreign.reload.position).to eq(free_slot)
      end

      it "refuses to swap someone else's rows through the user's own party" do
        own_party = create(:party, user: other_user)
        swap(first_row, second_row, party_id: own_party.id, with: other_headers)

        expect(response).to have_http_status(:not_found)
        expect(first_row.reload.position).to eq(first_slot)
        expect(second_row.reload.position).to eq(second_slot)
      end

      it "refuses someone else's party" do
        swap(first_row, second_row, with: other_headers)

        expect(response).to have_http_status(:unauthorized)
        expect(first_row.reload.position).to eq(first_slot)
      end

      context 'with an anonymous party' do
        let!(:anon_first) { create(:"grid_#{type}", party: anonymous_party, position: first_slot) }
        let!(:anon_second) { create(:"grid_#{type}", party: anonymous_party, position: second_slot) }

        it 'swaps with the right edit key' do
          swap(anon_first, anon_second, party_id: anonymous_party.id, with: edit_key_headers('test-edit-key'))

          expect(response).to have_http_status(:ok)
          expect(anon_first.reload.position).to eq(second_slot)
        end

        it 'refuses a wrong edit key' do
          swap(anon_first, anon_second, party_id: anonymous_party.id, with: edit_key_headers('wrong-key'))

          expect(response).to have_http_status(:unauthorized)
          expect(anon_first.reload.position).to eq(first_slot)
        end
      end
    end

    describe 'POST /grid_*/update_uncap' do
      def uncap(row, with: headers, **attrs)
        post "/api/v1/#{path}/update_uncap",
             params: { param_key => { id: row.id, uncap_level: 4, transcendence_step: 0 }.merge(attrs) }.to_json,
             headers: with
      end

      it 'updates the uncap level and returns the uncap view' do
        uncap(first_row)

        expect(response).to have_http_status(:ok)
        body = response.parsed_body
        expect(body.keys).to eq([root])
        expect(body[root]).to eq(rendered(first_row.reload, :uncap))
        expect(first_row.uncap_level).to eq(4)
      end

      it 'does not bump last_updated' do
        expect { uncap(first_row) }.not_to(change { party.reload.last_updated })
      end

      it "refuses someone else's party" do
        uncap(first_row, with: other_headers)

        expect(response).to have_http_status(:unauthorized)
        expect(first_row.reload.uncap_level).to eq(3)
      end

      context 'with an anonymous party' do
        let!(:anon_row) { create(:"grid_#{type}", party: anonymous_party, position: first_slot) }

        it 'updates with the right edit key' do
          uncap(anon_row, with: edit_key_headers('test-edit-key'))

          expect(response).to have_http_status(:ok)
          expect(anon_row.reload.uncap_level).to eq(4)
        end

        it 'refuses a wrong edit key' do
          uncap(anon_row, with: edit_key_headers('wrong-key'))

          expect(response).to have_http_status(:unauthorized)
          expect(anon_row.reload.uncap_level).to eq(3)
        end
      end
    end

    describe 'DELETE /grid_*/:id' do
      it 'removes the row and returns the destroyed view' do
        expected = rendered(first_row, :destroyed)
        delete "/api/v1/#{path}/#{first_row.id}", headers: headers

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq(expected)
        expect(first_row.class.exists?(first_row.id)).to be(false)
      end

      it "refuses someone else's party" do
        delete "/api/v1/#{path}/#{first_row.id}", headers: other_headers

        expect(response).to have_http_status(:unauthorized)
        expect(first_row.class.exists?(first_row.id)).to be(true)
      end

      it 'clears the collection source once the last linked row is gone' do
        party.update!(collection_source_user_id: user.id)
        delete "/api/v1/#{path}/#{first_row.id}", headers: headers

        expect(party.reload.collection_source_user_id).to be_nil
      end

      context 'with an anonymous party' do
        let!(:anon_row) { create(:"grid_#{type}", party: anonymous_party, position: first_slot) }

        it 'removes with the right edit key' do
          delete "/api/v1/#{path}/#{anon_row.id}", headers: edit_key_headers('test-edit-key')

          expect(response).to have_http_status(:ok)
          expect(anon_row.class.exists?(anon_row.id)).to be(false)
        end

        it 'refuses a wrong edit key' do
          delete "/api/v1/#{path}/#{anon_row.id}", headers: edit_key_headers('wrong-key')

          expect(response).to have_http_status(:unauthorized)
          expect(anon_row.class.exists?(anon_row.id)).to be(true)
        end
      end
    end

    describe 'collection sync' do
      let(:collection_item) { create(:"collection_#{type}", user: user, uncap_level: 4, transcendence_step: 0) }
      let!(:linked_row) do
        create(:"grid_#{type}", party: party, position: free_slot, uncap_level: 3,
                                type => collection_item.public_send(type),
                                "collection_#{type}" => collection_item)
      end

      describe 'POST /grid_*/:id/sync' do
        it 'copies the collection item onto the row' do
          post "/api/v1/#{path}/#{linked_row.id}/sync", headers: headers

          expect(response).to have_http_status(:ok)
          body = response.parsed_body
          expect(body.keys).to eq([root])
          expect(body[root]).to eq(rendered(linked_row.reload, view))
          expect(linked_row.uncap_level).to eq(4)
        end

        it 'only copies the requested fields' do
          post "/api/v1/#{path}/#{linked_row.id}/sync",
               params: { fields: ['transcendenceStep'] }.to_json, headers: headers

          expect(response).to have_http_status(:ok)
          expect(linked_row.reload.uncap_level).to eq(3)
        end

        it 'refuses a row without a linked collection item' do
          post "/api/v1/#{path}/#{first_row.id}/sync", headers: headers

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("No collection #{type} linked")
        end

        it "refuses someone else's party" do
          post "/api/v1/#{path}/#{linked_row.id}/sync", headers: other_headers

          expect(response).to have_http_status(:unauthorized)
          expect(linked_row.reload.uncap_level).to eq(3)
        end
      end

      describe 'POST /grid_*/:id/sync_to_collection' do
        before { party.update!(collection_source_user_id: user.id) }

        it 'copies the row onto the collection item' do
          post "/api/v1/#{path}/#{linked_row.id}/sync_to_collection", headers: headers

          expect(response).to have_http_status(:ok)
          body = response.parsed_body
          expect(body.keys).to eq([root])
          expect(body[root]).to eq(rendered(linked_row.reload, view))
          expect(collection_item.reload.uncap_level).to eq(3)
        end

        it 'refuses a row without a linked collection item' do
          post "/api/v1/#{path}/#{first_row.id}/sync_to_collection", headers: headers

          expect(response).to have_http_status(:unprocessable_content)
          expect(response.body).to include("No collection #{type} linked")
        end

        it 'refuses when the party does not draw from the user collection' do
          party.update!(collection_source_user_id: other_user.id)
          post "/api/v1/#{path}/#{linked_row.id}/sync_to_collection", headers: headers

          expect(response).to have_http_status(:unauthorized)
          expect(collection_item.reload.uncap_level).to eq(4)
        end

        it "refuses someone else's party" do
          post "/api/v1/#{path}/#{linked_row.id}/sync_to_collection", headers: other_headers

          expect(response).to have_http_status(:unauthorized)
          expect(collection_item.reload.uncap_level).to eq(4)
        end

        it "refuses a collection item that belongs to someone else's collection" do
          foreign_item = create(:"collection_#{type}", user: other_user, uncap_level: 4)
          linked_row.update_column(:"collection_#{type}_id", foreign_item.id)
          post "/api/v1/#{path}/#{linked_row.id}/sync_to_collection", headers: headers

          expect(response).to have_http_status(:unauthorized)
          expect(foreign_item.reload.uncap_level).to eq(4)
        end

        it 'refuses an anonymous party' do
          anon_row = create(:"grid_#{type}", party: anonymous_party, position: free_slot,
                                             type => collection_item.public_send(type))
          anon_row.update_column(:"collection_#{type}_id", collection_item.id)
          post "/api/v1/#{path}/#{anon_row.id}/sync_to_collection", headers: edit_key_headers('test-edit-key')

          expect(response).to have_http_status(:unauthorized)
          expect(collection_item.reload.uncap_level).to eq(4)
        end
      end
    end
  end

  describe 'grid weapons' do
    it_behaves_like 'shared grid actions', type: :weapon, view: :full, slots: [0, 2, 4], invalid_position: 20
  end

  describe 'grid characters' do
    it_behaves_like 'shared grid actions', type: :character, view: :nested, slots: [0, 1, 2], invalid_position: 8
  end

  describe 'grid summons' do
    it_behaves_like 'shared grid actions', type: :summon, view: :nested, slots: [0, 1, 2], invalid_position: 7
  end

  describe 'weapon specifics' do
    let(:blueprint) { Api::V1::GridWeaponBlueprint }

    def move(row, position)
      put "/api/v1/parties/#{party.id}/grid_weapons/#{row.id}/position",
          params: { position: position }.to_json, headers: headers
    end

    it 'sets the party element when a weapon moves into the mainhand' do
      row = create(:grid_weapon, party: party, position: 0, weapon: create(:weapon, element: 3))
      move(row, -1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.keys).to eq(%w[party grid_weapon])
      expect(party.reload.element).to eq(3)
    end

    it 'marks the party as extra when a weapon moves into an extra slot' do
      row = create(:grid_weapon, party: party, position: 0, weapon: create(:weapon, extra: true))
      move(row, 9)

      expect(response).to have_http_status(:ok)
      expect(party.reload.extra).to be(true)
    end

    it 'raises the uncap to the extra-slot prerequisite' do
      weapon = create(:weapon, extra: true, ulb: true, extra_prerequisite: 4)
      row = create(:grid_weapon, party: party, position: 9, weapon: weapon, uncap_level: 4)
      post '/api/v1/grid_weapons/update_uncap',
           params: { weapon: { id: row.id, uncap_level: 3 } }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(row.reload.uncap_level).to eq(4)
    end

    it 'caps the transcendence step at 5' do
      row = create(:grid_weapon, party: party, position: 0, weapon: create(:weapon, :transcendable))
      post '/api/v1/grid_weapons/update_uncap',
           params: { weapon: { id: row.id, uncap_level: 6, transcendence_step: 9 } }.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(row.reload.uncap_level).to eq(6)
      expect(row.transcendence_step).to eq(5)
    end
  end

  describe 'character specifics' do
    def move(row, position)
      put "/api/v1/parties/#{party.id}/grid_characters/#{row.id}/position",
          params: { position: position }.to_json, headers: headers
    end

    it 'reports no reorder when a character moves within the main slots' do
      row = create(:grid_character, party: party, position: 0)
      move(row, 3)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.keys).to eq(%w[party grid_character reordered])
      expect(response.parsed_body['reordered']).to be(false)
    end

    it 'compacts the main slots when a character moves in from an extra slot' do
      main = create(:grid_character, party: party, position: 1)
      extra = create(:grid_character, party: party, position: 5)
      move(extra, 3)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['reordered']).to be(true)
      expect(main.reload.position).to eq(0)
      expect(extra.reload.position).to eq(1)
    end
  end

  describe 'summon specifics' do
    def uncap(row, **attrs)
      post '/api/v1/grid_summons/update_uncap',
           params: { summon: { id: row.id }.merge(attrs) }.to_json, headers: headers
    end

    it 'keeps a summon that cannot transcend at step 0' do
      row = create(:grid_summon, party: party, position: 0, summon: create(:summon))
      uncap(row, uncap_level: 4, transcendence_step: 3)

      expect(response).to have_http_status(:ok)
      expect(row.reload.uncap_level).to eq(4)
      expect(row.transcendence_step).to eq(0)
    end

    it 'raises the uncap to the max when a transcendence step is sent' do
      row = create(:grid_summon, party: party, position: 0, summon: create(:summon, :transcendable))
      uncap(row, uncap_level: 3, transcendence_step: 7)

      expect(response).to have_http_status(:ok)
      expect(row.reload.uncap_level).to eq(6)
      expect(row.transcendence_step).to eq(5)
    end

    it 'refuses to move a summon into the main summon slot' do
      row = create(:grid_summon, party: party, position: 0)
      put "/api/v1/parties/#{party.id}/grid_summons/#{row.id}/position",
          params: { position: -1 }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Cannot move summon to restricted position -1')
    end

    it 'refuses to swap with the friend summon' do
      row = create(:grid_summon, party: party, position: 0)
      friend = create(:grid_summon, party: party, position: 6)
      post "/api/v1/parties/#{party.id}/grid_summons/swap",
           params: { source_id: row.id, target_id: friend.id }.to_json, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Cannot swap summons in restricted positions')
      expect(friend.reload.position).to eq(6)
    end
  end
end
