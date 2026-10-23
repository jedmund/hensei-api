# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ExtensionAuthCodes::CleanupJob, type: :job do
  let(:user) { create(:user) }
  let(:challenge) { ExtensionAuthCode.challenge_for(SecureRandom.urlsafe_base64(32)) }

  it 'deletes expired codes and keeps live ones' do
    ExtensionAuthCode.issue(user, code_challenge: challenge)
    used = ExtensionAuthCode.issue(user, code_challenge: challenge)
    ExtensionAuthCode.find_by(code_digest: ExtensionAuthCode.digest(used)).claim!

    travel(61.seconds) do
      live = ExtensionAuthCode.issue(user, code_challenge: challenge)

      described_class.perform_now

      expect(ExtensionAuthCode.pluck(:code_digest)).to eq([ExtensionAuthCode.digest(live)])
    end
  end

  it 'is scheduled daily' do
    schedule = YAML.load_file(Rails.root.join('config/sidekiq.yml')).dig(:scheduler, :schedule)
    expect(schedule['extension_auth_code_cleanup']).to include('class' => described_class.name, 'queue' => 'maintenance')
  end
end
