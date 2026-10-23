# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CharacterSkills::IconDownloadJob do
  let(:results) { { '1_1' => { success: true }, '2_2' => { success: true, skipped: true }, '3_3' => { success: false, error: '404' } } }

  before do
    allow(Granblue::Downloaders::AbilityIconDownloader).to receive(:new) do |stem, **|
      instance_double(Granblue::Downloaders::AbilityIconDownloader, download: results.fetch(stem))
    end
    allow_any_instance_of(described_class).to receive(:throttle)
  end

  it 'downloads each stem once to S3, skipping stored icons and counting failures' do
    counts = described_class.perform_now(%w[1_1 2_2 3_3 1_1])
    expect(counts).to eq(downloaded: 1, skipped: 1, failed: 1)
    expect(Granblue::Downloaders::AbilityIconDownloader).to have_received(:new).with('1_1', storage: :s3, logger: Rails.logger).once
  end

  it 'waits between downloads, not after skips' do
    job = described_class.new
    allow(job).to receive(:throttle)
    job.perform(%w[1_1 2_2])
    expect(job).to have_received(:throttle).once
  end
end
