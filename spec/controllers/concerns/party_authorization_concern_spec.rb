# frozen_string_literal: true

require 'rails_helper'

# Dummy controller that includes the PartyAuthorizationConcern.
# This allows us to test its instance methods in isolation.
class DummyAuthorizationController < ActionController::Base
  include PartyAuthorizationConcern

  attr_accessor :party, :current_user, :edit_key

  # Override render_unauthorized_response to set a flag.
  def render_unauthorized_response
    @_unauthorized_called = true
  end

  def unauthorized_called?
    @_unauthorized_called || false
  end
end

RSpec.describe DummyAuthorizationController, type: :controller do
  let(:dummy_controller) { DummyAuthorizationController.new }
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:anonymous_party) { create(:party, user: nil, edit_key: 'anonkey') }
  let(:owned_party) { create(:party, user: user) }

  describe '#authorize_party!' do
    context 'when the party belongs to a logged in user' do
      before do
        dummy_controller.party = owned_party
      end

      context 'and current_user matches party.user' do
        before { dummy_controller.current_user = user }
        it 'does not call render_unauthorized_response' do
          dummy_controller.authorize_party!
          expect(dummy_controller.unauthorized_called?).to be false
        end
      end

      context 'and current_user is missing or does not match' do
        before { dummy_controller.current_user = other_user }
        it 'calls render_unauthorized_response' do
          dummy_controller.authorize_party!
          expect(dummy_controller.unauthorized_called?).to be true
        end
      end
    end

    context 'when the party is anonymous (no user)' do
      before do
        dummy_controller.party = anonymous_party
      end

      context 'with a valid edit_key' do
        before { dummy_controller.edit_key = 'anonkey' }
        it 'does not call render_unauthorized_response' do
          dummy_controller.authorize_party!
          expect(dummy_controller.unauthorized_called?).to be false
        end
      end

      context 'with an invalid edit_key' do
        before { dummy_controller.edit_key = 'wrongkey' }
        it 'calls render_unauthorized_response' do
          dummy_controller.authorize_party!
          expect(dummy_controller.unauthorized_called?).to be true
        end
      end
    end
  end

  describe '#not_owner?' do
    context 'when the party belongs to a logged in user' do
      before do
        dummy_controller.party = owned_party
      end

      context 'and current_user matches party.user' do
        before { dummy_controller.current_user = user }
        it 'returns false' do
          expect(dummy_controller.not_owner?).to be false
        end
      end

      context 'and current_user does not match party.user' do
        before { dummy_controller.current_user = other_user }
        it 'returns true' do
          expect(dummy_controller.not_owner?).to be true
        end
      end
    end

    context 'when the party is anonymous' do
      before do
        dummy_controller.party = anonymous_party
      end

      context 'and the provided edit_key matches' do
        before { dummy_controller.edit_key = 'anonkey' }
        it 'returns false' do
          expect(dummy_controller.not_owner?).to be false
        end
      end

      context 'and the provided edit_key does not match' do
        before { dummy_controller.edit_key = 'wrongkey' }
        it 'returns true' do
          expect(dummy_controller.not_owner?).to be true
        end
      end
    end
  end

  # Debug block: prints debug info if an example fails.
  after(:each) do |example|
    if example.exception && defined?(response) && response.present?
      error_message = begin
                        JSON.parse(response.body)['exception']
                      rescue JSON::ParserError
                        response.body
                      end

      puts "\nDEBUG: Error Message for '#{example.full_description}': #{error_message}"

      # Parse once and grab the trace safely
      parsed_body = JSON.parse(response.body)
      trace = parsed_body.dig('traces', 'Application Trace')
      ap trace if trace # Only print if trace is not nil
    end
  end
end
