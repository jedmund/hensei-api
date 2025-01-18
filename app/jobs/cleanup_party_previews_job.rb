class CleanupPartyPreviewsJob < ApplicationJob
  queue_as :maintenance

  def perform
    Party.where(preview_state: :generated)
         .where('preview_generated_at < ?', PreviewService::Coordinator::PREVIEW_EXPIRY.ago)
         .find_each do |party|
      PreviewService::Coordinator.new(party).delete_preview
    end
  end
end
