# frozen_string_literal: true

require 'rails_helper'

# The requests Dataminer sends to the game and what it records for each answer.
# Cookie values here are placeholders.
RSpec.describe Dataminer do
  let(:archive) { %r{\Ahttps://game\.granbluefantasy\.jp/archive/} }
  let(:payload) { { 'id' => '1040001000', 'name' => 'Sword', 'skill1' => { 'name' => 'Might' } } }
  let(:log) { StringIO.new }

  let(:miner) do
    described_class.new(page: 'archive', access_token: 'token-value', wing: 'wing-value', midship: 'midship-1',
                        user_id: '123', game_version: '999').tap do |m|
      m.instance_variable_set(:@logger, Logger.new(log))
      allow(m).to receive(:sleep)
    end
  end

  def answer(body, headers: {})
    { status: 200, body: body.to_json, headers: { 'Content-Type' => 'application/json' }.merge(headers) }
  end

  describe '#fetch_weapon' do
    let!(:weapon) { create(:weapon, granblue_id: '1040001000') }

    it 'posts the detail request with the session cookies and stores the payload' do
      request = stub_request(:post, %r{archive/weapon_detail\?_=\d+&t=\d+&uid=123\z})
                .with(body: { special_token: nil, user_id: '123', kind_name: '0', attribute: '0', event_id: nil,
                              story_id: nil, weapon_id: '1040001000' }.to_json,
                      headers: { 'Cookie' => 'access_gbtk=token-value; wing=wing-value; t=dummy; midship=midship-1',
                                 'X-VERSION' => '999', 'Content-Type' => 'application/json' })
                .to_return(answer(payload))

      expect(miner.fetch_weapon('1040001000')).to eq(payload)
      expect(request).to have_been_requested.once
      expect(weapon.reload.game_raw_en).to include('name' => 'Sword')
      expect([miner.summary.fetched, miner.summary.changed]).to eq([1, 1])
    end

    it 'counts an unchanged payload as fetched but not changed' do
      stub_request(:post, archive).to_return(answer(payload))
      miner.fetch_weapon('1040001000')
      miner.fetch_weapon('1040001000')

      expect([miner.summary.fetched, miner.summary.changed]).to eq([2, 1])
    end

    it 'skips a weapon that is not in the database' do
      stub_request(:post, archive).to_return(answer(payload))
      miner.fetch_weapon('1049999999')

      expect(miner.summary.skips).to eq('not in database' => 1)
    end

    it 'follows the rotating midship cookie' do
      stub_request(:post, archive).to_return(answer(payload, headers: { 'Set-Cookie' => 'midship=midship-2; path=/' }))
      miner.fetch_weapon('1040001000')
      miner.fetch_weapon('1040001000')

      expect(WebMock).to have_requested(:post, archive).with(headers: { 'Cookie' => /midship=midship-2\z/ }).once
    end

    it 'keeps cookie values out of the debug log' do
      debug_miner = described_class.new(page: 'archive', access_token: 'token-value', wing: 'wing-value',
                                        midship: 'midship-1', debug: true)
      debug_miner.instance_variable_set(:@logger, Logger.new(log))
      stub_request(:post, archive).to_return(answer(payload, headers: { 'Set-Cookie' => 'midship=midship-2; path=/' }))

      debug_miner.fetch_weapon('1040001000')

      expect(log.string).to include('=== Request Details ===', 'access_gbtk=[FILTERED]', 'Response code: 200')
      expect(log.string).not_to include('token-value', 'wing-value', 'midship-1', 'midship-2')
    end

    it 'raises on an authentication failure' do
      stub_request(:post, archive).to_return(answer({ 'auth_status' => 'require_auth' }))

      expect { miner.fetch_weapon('1040001000') }.to raise_error(Dataminer::AuthenticationError)
    end

    it 'treats a response that is not JSON as an authentication failure' do
      stub_request(:post, archive).to_return(status: 200, body: '<html>')

      expect { miner.fetch_weapon('1040001000') }.to raise_error(Dataminer::AuthenticationError)
    end
  end

  describe '#fetch_summon' do
    let!(:summon) { create(:summon, granblue_id: '2040001000') }

    it 'posts the summon id and stores the payload' do
      request = stub_request(:post, %r{archive/summon_detail})
                .with(body: hash_including('summon_id' => '2040001000', 'kind_name' => '0'))
                .to_return(answer(payload.merge('id' => '2040001000')))

      miner.fetch_summon('2040001000')

      expect(request).to have_been_requested.once
      expect(summon.reload.game_raw_en).to include('name' => 'Sword')
    end
  end

  describe '#fetch_all_summons' do
    it 'fetches every summon, or only those without a payload' do
      create(:summon, granblue_id: '2040001001', game_raw_en: { 'id' => 'x' })
      create(:summon, granblue_id: '2040001002')
      stub_request(:post, %r{archive/summon_detail}).to_return(answer(payload))
      without = Summon.without_source(:game_raw_en).count

      miner.fetch_all_summons(only_missing: true)

      expect(WebMock).to have_requested(:post, %r{archive/summon_detail}).times(without)
      expect(WebMock).not_to have_requested(:post, %r{archive/summon_detail}).with(body: hash_including('summon_id' => '2040001001'))
      expect(log.string).to include("Total: #{without}", "Successful: #{without}", 'Failed: 0')
    end
  end

  describe 'storing errors' do
    it 'records a record that fails to save' do
      weapon = create(:weapon, granblue_id: '1040001000')
      allow(Weapon).to receive(:find_by).with(granblue_id: '1040001000').and_return(weapon)
      allow(weapon).to receive(:update).and_return(false)
      weapon.errors.add(:base, 'broken')
      stub_request(:post, archive).to_return(answer(payload))

      miner.fetch_weapon('1040001000')

      expect(miner.summary.errors.map { |e| [e.granblue_id, e.message] }).to eq([%w[1040001000 broken]])
    end

    it 'records an unknown language as an error' do
      create(:weapon, granblue_id: '1040001000')
      miner.send(:payload_store).store('Weapon', '1040001000', payload, lang: 'fr')

      expect(miner.summary.errors.map(&:message)).to eq(['unknown lang "fr"'])
    end

    it 'ignores a response that is not a hash' do
      miner.send(:payload_store).store('Weapon', '1040001000', ['list'])

      expect([miner.summary.fetched, miner.summary.skipped, miner.summary.errors]).to eq([0, 0, []])
    end
  end
end
