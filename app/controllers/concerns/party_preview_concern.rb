# frozen_string_literal: true

module PartyPreviewConcern
  extend ActiveSupport::Concern

  # Schedules preview generation for this party.
  def schedule_preview_generation
    GeneratePartyPreviewJob.perform_later(id)
  end

  # Handles serving the party preview image.
  def party_preview(party)
    coordinator = PreviewService::Coordinator.new(party)
    if coordinator.generation_in_progress?
      response.headers['Retry-After'] = '2'
      default_path = Rails.root.join('public', 'default-previews', "#{party.element || 'default'}.png")
      send_file default_path, type: 'image/png', disposition: 'inline'
      return
    end
    begin
      if Rails.env.production?
        s3_object = coordinator.get_s3_object
        send_data s3_object.body.read, filename: "#{party.shortcode}.png", type: 'image/png', disposition: 'inline'
      else
        send_file coordinator.local_preview_path, type: 'image/png', disposition: 'inline'
      end
    rescue Aws::S3::Errors::NoSuchKey
      coordinator.schedule_generation unless coordinator.generation_in_progress?
      send_file Rails.root.join('public', 'default-previews', "#{party.element || 'default'}.png"), type: 'image/png', disposition: 'inline'
    end
  end
end
