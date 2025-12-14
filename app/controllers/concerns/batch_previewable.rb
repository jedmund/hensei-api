# frozen_string_literal: true

# Provides batch wiki preview functionality for entity controllers
module BatchPreviewable
  extend ActiveSupport::Concern

  private

  # Process a single wiki page and return preview data
  # @param wiki_page [String] The wiki page name to fetch
  # @param entity_type [Symbol] The type of entity (:character, :weapon, :summon)
  # @param wiki_raw [String, nil] Pre-fetched wiki text (from client-side fetch)
  # @return [Hash] Preview data including status, suggestions, and errors
  def process_wiki_preview(wiki_page, entity_type, wiki_raw: nil)
    result = {
      wiki_page: wiki_page,
      status: 'success'
    }

    begin
      # Use provided wiki_raw or fetch from wiki
      wiki_text = if wiki_raw.present?
                    wiki_raw
                  else
                    wiki = Granblue::Parsers::Wiki.new
                    wiki.fetch(wiki_page)
                  end

      # Handle redirects (only if we fetched server-side)
      if wiki_raw.blank?
        redirect_match = wiki_text.match(/#REDIRECT \[\[(.*?)\]\]/)
        if redirect_match
          redirect_target = redirect_match[1]
          result[:redirected_from] = wiki_page
          result[:wiki_page] = redirect_target
          wiki_text = wiki.fetch(redirect_target)
        end
      end

      result[:wiki_raw] = wiki_text

      # Parse suggestions based on entity type
      suggestions = case entity_type
                    when :character
                      Granblue::Parsers::SuggestionParser.parse_character(wiki_text)
                    when :weapon
                      Granblue::Parsers::SuggestionParser.parse_weapon(wiki_text)
                    when :summon
                      Granblue::Parsers::SuggestionParser.parse_summon(wiki_text)
                    end

      result[:granblue_id] = suggestions[:granblue_id] if suggestions[:granblue_id].present?
      result[:suggestions] = suggestions

      # Queue image download if we have a granblue_id
      if suggestions[:granblue_id].present?
        result[:image_status] = queue_image_download(suggestions[:granblue_id], entity_type)
      else
        result[:image_status] = 'no_id'
      end
    rescue Granblue::WikiError => e
      result[:status] = 'error'
      result[:error] = "Wiki page not found: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "[BATCH_PREVIEW] Error processing #{wiki_page}: #{e.message}"
      result[:status] = 'error'
      result[:error] = "Failed to process wiki page: #{e.message}"
    end

    result
  end

  # Queue an image download job for the entity
  # @param granblue_id [String] The granblue ID to download images for
  # @param entity_type [Symbol] The type of entity
  # @return [String] Status of the image download ('queued', 'skipped', 'error')
  def queue_image_download(granblue_id, entity_type)
    # Check if entity already exists in database
    model_class = case entity_type
                  when :character then Character
                  when :weapon then Weapon
                  when :summon then Summon
                  end

    existing = model_class.find_by(granblue_id: granblue_id)
    if existing
      # Entity exists, skip download (images likely already exist)
      return 'exists'
    end

    # For now, we don't queue the download since the entity doesn't exist yet
    # The image download will happen after the entity is created
    'pending'
  rescue StandardError => e
    Rails.logger.error "[BATCH_PREVIEW] Error queueing image download: #{e.message}"
    'error'
  end
end
