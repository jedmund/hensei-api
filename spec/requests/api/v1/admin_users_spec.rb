# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Admin users', type: :request do
  let(:admin) { create(:user, role: 9, username: 'theadmin') }
  let(:editor) { create(:user, role: 7) }
  let!(:member) { create(:user, role: 1, username: 'member', email: 'member@example.com') }

  def auth_headers(account)
    token = Doorkeeper::AccessToken.create!(resource_owner_id: account.id, expires_in: 30.days, scopes: 'public')
    { 'Authorization' => "Bearer #{token.token}", 'Content-Type' => 'application/json' }
  end

  def patch_role(target, role, as: admin)
    patch "/api/v1/admin/users/#{target.id}/role", params: { role: role }.to_json, headers: auth_headers(as)
  end

  describe 'access' do
    it 'turns away editors and anonymous requests on every endpoint' do
      [auth_headers(editor), {}].each do |headers|
        get '/api/v1/admin/users', headers: headers
        expect(response).to have_http_status(:unauthorized)
        get "/api/v1/admin/users/#{member.id}", headers: headers
        expect(response).to have_http_status(:unauthorized)
        patch "/api/v1/admin/users/#{member.id}/role", params: { role: 7 }.to_json, headers: headers
        expect(response).to have_http_status(:unauthorized)
      end
      expect(member.reload.role).to eq(1)
    end
  end

  describe 'GET /admin/users' do
    it 'lists users with their email for admins' do
      get '/api/v1/admin/users', headers: auth_headers(admin)

      expect(response).to have_http_status(:ok)
      row = response.parsed_body['results'].find { |r| r['username'] == 'member' }
      expect(row).to include('email' => 'member@example.com', 'role' => 1)
    end

    it 'searches usernames, display names and email with q' do
      create(:user, username: 'membership', email: 'other@example.com')

      get '/api/v1/admin/users', params: { q: 'member' }, headers: auth_headers(admin)
      expect(response.parsed_body['results'].pluck('username')).to contain_exactly('member', 'membership')

      get '/api/v1/admin/users', params: { q: 'member@example' }, headers: auth_headers(admin)
      expect(response.parsed_body['results'].pluck('username')).to eq(['member'])
    end

    it 'keeps searches that look like an email out of the logs' do
      filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
      expect(filter.filter('q' => 'member@example.com')).to eq('q' => '[FILTERED]')
      expect(filter.filter('q' => 'member')).to eq('q' => 'member')
    end

    it 'filters by role' do
      editor
      get '/api/v1/admin/users', params: { filter: { role: '7' } }, headers: auth_headers(admin)
      expect(response.parsed_body['results'].pluck('role').uniq).to eq([7])
    end
  end

  describe 'GET /admin/users/:id' do
    it 'shows the profile, team count and history' do
      create(:party, user: member)
      patch_role(member, 6)

      get "/api/v1/admin/users/#{member.id}", headers: auth_headers(admin)

      body = response.parsed_body
      expect(body).to include('username' => 'member', 'email' => 'member@example.com', 'role' => 6, 'party_count' => 1)
      expect(body['history'].first).to include('kind' => 'role', 'from_role' => 1, 'to_role' => 6,
                                               'actor' => include('username' => 'theadmin'))
    end

    it '404s for an unknown id' do
      get "/api/v1/admin/users/#{SecureRandom.uuid}", headers: auth_headers(admin)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /admin/users/:id/role' do
    it 'changes the role and logs it once' do
      expect { patch_role(member, 7) }.to change(UserAccessChange, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(member.reload.role).to eq(7)
      expect(UserAccessChange.last).to have_attributes(user: member, actor: admin, kind: 'role', from_role: 1,
                                                       to_role: 7)
    end

    it 'takes effect on the next API request' do
      patch_role(member, 7)
      get '/api/v1/admin/events', headers: auth_headers(member)
      expect(response).to have_http_status(:ok)

      patch_role(member, 1)
      get '/api/v1/admin/events', headers: auth_headers(member)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'logs nothing when the role is unchanged' do
      expect { patch_role(member, 1) }.not_to change(UserAccessChange, :count)
      expect(response).to have_http_status(:ok)
    end

    it "refuses the admin's own account" do
      expect { patch_role(admin, 7) }.not_to change(UserAccessChange, :count)
      expect(response).to have_http_status(:forbidden)
      expect(admin.reload.role).to eq(9)
    end

    it 'refuses to change another admin' do
      other_admin = create(:user, role: 9)
      patch_role(other_admin, 1)
      expect(response).to have_http_status(:unprocessable_content)
      expect(other_admin.reload.role).to eq(9)
    end

    it 'refuses roles outside user, curator and editor' do
      [9, 0, 5, 'editor'].each do |role|
        patch_role(member, role)
        expect(response).to have_http_status(:unprocessable_content)
      end
      expect(member.reload.role).to eq(1)
      expect(UserAccessChange.count).to eq(0)
    end
  end

  describe 'account deletion' do
    it 'keeps the log but drops the links to deleted accounts' do
      patch_role(member, 6)
      change = UserAccessChange.last

      member.destroy!
      admin.destroy!

      expect(change.reload).to have_attributes(user_id: nil, actor_id: nil, kind: 'role', to_role: 6)
    end
  end

  it 'never shows email in the public user views' do
    get "/api/v1/users/#{member.username}"
    expect(response.parsed_body.to_s).not_to include('member@example.com')
  end
end
