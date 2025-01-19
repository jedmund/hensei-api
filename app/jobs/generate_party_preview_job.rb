# app/jobs/generate_party_preview_job.rb
class GeneratePartyPreviewJob < ApplicationJob
  queue_as :previews

  # Configure retry behavior
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  discard_on ActiveRecord::RecordNotFound do |job, error|
    Rails.logger.error("Party #{job.arguments.first} not found for preview generation")
  end

  around_perform :track_timing

  def perform(party_id)
    Rails.logger.info("Starting preview generation for party #{party_id}")
    Rails.logger.info("Debug: should_generate? check starting")

    party = Party.find(party_id)
    Rails.logger.info("Party found: #{party.inspect}")

    if party.preview_state == 'generated' &&
      party.preview_generated_at &&
      party.preview_generated_at > 1.hour.ago
      Rails.logger.info("Skipping preview generation - recent preview exists")
      return
    end

    begin
      Rails.logger.info("Initializing PreviewService::Coordinator")
      service = PreviewService::Coordinator.new(party)
      Rails.logger.info("Coordinator initialized")

      Rails.logger.info("Checking should_generate?")
      should_gen = service.send(:should_generate?)
      Rails.logger.info("should_generate? returned: #{should_gen}")

      if !should_gen
        Rails.logger.info("Not generating preview because should_generate? returned false")
        Rails.logger.info("Preview state: #{party.preview_state}")
        Rails.logger.info("Generation in progress: #{service.send(:generation_in_progress?)}")
        return
      end

      Rails.logger.info("Starting generate_preview")
      result = service.generate_preview
      Rails.logger.info("Generate preview result: #{result}")

      if result
        Rails.logger.info("Successfully generated preview for party #{party_id}")
      else
        Rails.logger.error("Failed to generate preview for party #{party_id}")
        notify_failure(party)
      end
    rescue => e
      Rails.logger.error("Error generating preview for party #{party_id}: #{e.message}")
      Rails.logger.error("Full error details:")
      Rails.logger.error(e.full_message)
      notify_failure(party, e)
      raise
    end
  end

  private

  def track_timing
    start_time = Time.current
    job_id = job_id

    Rails.logger.info("Preview generation job #{job_id} starting")

    yield

    duration = Time.current - start_time
    Rails.logger.info("Preview generation job #{job_id} completed in #{duration.round(2)}s")

    # Track metrics if you have a metrics service
    # StatsD.timing("preview_generation.duration", duration * 1000)
  end

  def notify_failure(party, error = nil)
    # Log to error tracking service if you have one
    # Sentry.capture_exception(error) if error

    # You could also notify admins through Slack/email for critical failures
    message = if error
                "Preview generation failed for party #{party.id} with error: #{error.message}"
              else
                "Preview generation failed for party #{party.id}"
              end

    # SlackNotifier.notify(message) # If you have Slack integration
  end
end
