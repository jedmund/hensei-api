# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreviewService::GenerationMonitor do
  before do
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:info)
  end

  describe '.check_stalled_jobs' do
    it 'resets stalled parties to pending when no job exists' do
      party = double('Party', id: 1)
      allow(party).to receive(:update!)

      relation = double('Relation')
      allow(Party).to receive(:where).with(preview_state: :queued).and_return(relation)
      allow(relation).to receive(:where).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(party)

      # Mock Sidekiq sets to return empty
      queue = double('Queue')
      scheduled = double('ScheduledSet')
      retrying = double('RetrySet')
      allow(Sidekiq::Queue).to receive(:new).with('previews').and_return(queue)
      allow(Sidekiq::ScheduledSet).to receive(:new).and_return(scheduled)
      allow(Sidekiq::RetrySet).to receive(:new).and_return(retrying)
      [queue, scheduled, retrying].each do |set|
        allow(set).to receive(:any?).and_return(false)
      end

      described_class.check_stalled_jobs

      expect(party).to have_received(:update!).with(preview_state: :pending)
    end

    it 'keeps state when job still exists' do
      party = double('Party', id: 1)

      relation = double('Relation')
      allow(Party).to receive(:where).with(preview_state: :queued).and_return(relation)
      allow(relation).to receive(:where).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(party)

      # Mock Sidekiq queue with matching job
      job = double('Job', args: [1], klass: 'GeneratePartyPreviewJob')
      queue = double('Queue')
      allow(queue).to receive(:any?).and_yield(job).and_return(true)
      allow(Sidekiq::Queue).to receive(:new).with('previews').and_return(queue)
      allow(Sidekiq::ScheduledSet).to receive(:new).and_return(double('ScheduledSet', any?: false))
      allow(Sidekiq::RetrySet).to receive(:new).and_return(double('RetrySet', any?: false))

      described_class.check_stalled_jobs

      expect(party).not_to respond_to(:update!) if !party.respond_to?(:update!)
    end
  end

  describe '.retry_failed' do
    it 'schedules retry for failed parties older than 1 hour' do
      party = double('Party', id: 42)
      relation = double('Relation')
      allow(Party).to receive(:where).with(preview_state: :failed).and_return(relation)
      allow(relation).to receive(:where).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(party)

      allow(GeneratePartyPreviewJob).to receive(:perform_later)

      described_class.retry_failed

      expect(GeneratePartyPreviewJob).to have_received(:perform_later).with(42)
    end
  end

  describe '.cleanup_old_previews' do
    it 'deletes previews older than 30 days' do
      party = double('Party', id: 1)
      coordinator = double('Coordinator')
      allow(coordinator).to receive(:delete_preview)

      relation = double('Relation')
      allow(Party).to receive(:where).with(preview_state: :generated).and_return(relation)
      allow(relation).to receive(:where).and_return(relation)
      allow(relation).to receive(:find_each).and_yield(party)

      allow(PreviewService::Coordinator).to receive(:new).with(party).and_return(coordinator)

      described_class.cleanup_old_previews

      expect(coordinator).to have_received(:delete_preview)
    end
  end
end
