# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::V1::Notifications', type: :request do
  let(:owner) { create(:user) }
  let(:party) { create(:party, user: owner, visibility: 1, name: 'Mine') }
  let(:headers) { bearer_headers(owner) }

  def give_sticker(to: party)
    create(:party_sticker, party: to, user: create(:user), sticker: create(:sticker))
  end

  describe 'GET /api/v1/notifications' do
    it 'returns 401 when signed out' do
      get '/api/v1/notifications'
      expect(response).to have_http_status(:unauthorized)
    end

    it "lists only the current user's notifications, newest first" do
      give_sticker
      remixer = create(:user)
      create(:party, user: remixer, source_party: party, remix: true, visibility: 1)
      give_sticker(to: create(:party, user: create(:user), visibility: 1))

      get '/api/v1/notifications', headers: headers

      body = response.parsed_body
      expect(response).to have_http_status(:ok)
      expect(body['notifications'].pluck('kind')).to eq(%w[party_remixed sticker_received])
      expect(body['unread_count']).to eq(2)
      expect(body['meta']).to include('count' => 2)
    end

    it 'never shows who gave a sticker' do
      give_sticker

      get '/api/v1/notifications', headers: headers

      row = response.parsed_body['notifications'].sole
      expect(row['actor']).to be_nil
      expect(row).not_to have_key('payload')
      expect(row['party']).to eq('shortcode' => party.shortcode, 'name' => 'Mine')
      expect(row['sticker']).to include('slug')
    end

    it 'names the remixer and links the remix only while it is public' do
      remixer = create(:user, username: 'remixer')
      remix = create(:party, user: remixer, source_party: party, remix: true, visibility: 1)

      get '/api/v1/notifications', headers: headers
      row = response.parsed_body['notifications'].sole
      expect(row['actor']).to include('username' => 'remixer')
      expect(row['remix']).to include('shortcode' => remix.shortcode)

      remix.update!(visibility: 3)
      get '/api/v1/notifications', headers: headers
      row = response.parsed_body['notifications'].sole
      expect(row['actor']).to be_nil
      expect(row['remix']).to be_nil
    end

    it 'notifies the source owner through the remix endpoint, once' do
      remixer = create(:user)

      expect do
        post "/api/v1/parties/#{party.shortcode}/remix", params: {}.to_json,
                                                         headers: bearer_headers(remixer).merge('Content-Type' => 'application/json')
      end.to change(Notification, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(Notification.sole).to have_attributes(recipient_id: owner.id, subject: party, actor_id: remixer.id)
    end

    it 'skips a row whose subject is gone' do
      give_sticker
      owner.notifications.update_all(subject_id: SecureRandom.uuid)

      get '/api/v1/notifications', headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['notifications']).to eq([])
    end

    it 'shows the state of a crew invitation' do
      invitation = create(:crew_invitation, user: owner)

      get '/api/v1/notifications', headers: headers
      row = response.parsed_body['notifications'].sole
      expect(row).to include('kind' => 'crew_invited', 'state' => 'pending')
      expect(row['crew']).to include('id' => invitation.crew_id)
      expect(row['invitation_id']).to eq(invitation.id)

      invitation.update!(expires_at: 1.minute.ago)
      get '/api/v1/notifications', headers: headers
      expect(response.parsed_body['notifications'].sole['state']).to eq('expired')
      expect(response.parsed_body['unread_count']).to eq(0)
    end
  end

  describe 'unread count and seen' do
    it 'clears passive rows when opened, but keeps counting pending invitations' do
      give_sticker
      create(:crew_invitation, user: owner)

      get '/api/v1/notifications/unread_count', headers: headers
      expect(response.parsed_body['unread_count']).to eq(2)

      post '/api/v1/notifications/seen', headers: headers
      expect(response.parsed_body['unread_count']).to eq(1)
    end

    it 'counts a grouped row again when it gains a sticker after being seen' do
      give_sticker
      post '/api/v1/notifications/seen', headers: headers
      travel 1.second
      give_sticker

      get '/api/v1/notifications/unread_count', headers: headers
      expect(response.parsed_body['unread_count']).to eq(1)
    end
  end

  describe 'POST /api/v1/notifications/:id/read' do
    it 'marks the notification read without moving it' do
      give_sticker
      notification = owner.notifications.sole

      expect { post "/api/v1/notifications/#{notification.id}/read", headers: headers }
        .not_to(change { notification.reload.updated_at })

      expect(response).to have_http_status(:no_content)
      expect(notification.reload.read_at).to be_present
    end

    it "returns 404 for someone else's notification" do
      other = create(:user)
      give_sticker(to: create(:party, user: other, visibility: 1))
      notification = other.notifications.sole

      post "/api/v1/notifications/#{notification.id}/read", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(notification.reload.read_at).to be_nil
    end
  end

  describe 'POST /api/v1/notifications/read_all' do
    it "marks only the current user's notifications read" do
      give_sticker
      other = create(:user)
      give_sticker(to: create(:party, user: other, visibility: 1))

      post '/api/v1/notifications/read_all', headers: headers

      expect(response).to have_http_status(:no_content)
      expect(owner.notifications.unread).to be_empty
      expect(other.notifications.unread.count).to eq(1)
    end
  end

  it 'deletes notifications with their team' do
    give_sticker
    expect { party.destroy! }.to change(Notification, :count).by(-1)
  end
end
