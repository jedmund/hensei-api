# app/services/preview_generation_monitor.rb
module PreviewService
  class PreviewGenerationMonitor
    class << self
      def check_stalled_jobs
        Party.where(preview_state: :queued)
             .where('updated_at < ?', 10.minutes.ago)
             .find_each do |party|
          Rails.logger.warn("Found stalled preview generation for party #{party.id}")

          # If no job is actually queued, reset the state
          unless job_exists?(party)
            party.update!(preview_state: :pending)
            Rails.logger.info("Reset stalled party #{party.id} to pending state")
          end
        end
      end

      def retry_failed
        Party.where(preview_state: :failed)
             .where('updated_at < ?', 1.hour.ago)
             .find_each do |party|
          Rails.logger.info("Retrying failed preview generation for party #{party.id}")
          GeneratePartyPreviewJob.perform_later(party.id)
        end
      end

      def cleanup_old_previews
        Party.where(preview_state: :generated)
             .where('preview_generated_at < ?', 30.days.ago)
             .find_each do |party|
          PreviewService::Coordinator.new(party).delete_preview
        end
      end

      private

      def job_exists?(party)
        # Implementation depends on your job backend
        # For Sidekiq:
        queue = Sidekiq::Queue.new('previews')
        scheduled = Sidekiq::ScheduledSet.new
        retrying = Sidekiq::RetrySet.new

        [queue, scheduled, retrying].any? do |set|
          set.any? do |job|
            job.args.first == party.id &&
              job.klass == 'GeneratePartyPreviewJob'
          end
        end
      end
    end
  end
end
