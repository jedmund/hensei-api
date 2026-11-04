# frozen_string_literal: true

# Provides batch wiki preview functionality for entity controllers
module BatchPreviewable
  extend ActiveSupport::Concern

  private

  # The batch preview hands the fetched wikitext to the client, which saves it
  # through create/update. Date it when it's written: stamp wiki_raw_fetched_at
  # whenever the submitted wiki_raw is non-blank and differs from what's stored.
  # @param attrs [ActionController::Parameters] permitted entity params
  # @param record [ApplicationRecord, nil] the existing entity (nil on create)
  # @return [ActionController::Parameters] attrs, stamped when wiki_raw changes
  def with_wiki_fetch_date(attrs, record = nil)
    return attrs unless attrs.key?(:wiki_raw) && attrs[:wiki_raw].present?
    return attrs if record && record.wiki_raw == attrs[:wiki_raw]

    attrs.merge(wiki_raw_fetched_at: Time.current)
  end

  # Process a single wiki page and return preview data
  # @param wiki_page [String] The wiki page name to fetch
  # @param entity_type [Symbol] The type of entity (:character, :weapon, :summon)
  # @param wiki_raw [String, nil] Pre-fetched wiki text (from client-side fetch)
  # @return [Hash] Preview data including status, parsed_data, and errors
  def process_wiki_preview(wiki_page, entity_type, wiki_raw: nil)
    result = {
      wiki_page: wiki_page,
      status: 'success'
    }

    begin
      # Use provided wiki_raw or fetch from wiki
      wiki_text = wiki_raw.presence || fetch_wiki_preview_text(wiki_page, result)
      result[:wiki_raw] = wiki_text

      parsed_data = parse_wiki_preview(wiki_text, entity_type)
      result[:granblue_id] = parsed_data[:granblue_id] if parsed_data[:granblue_id].present?
      result[:parsed_data] = parsed_data

      # Queue image download if we have a granblue_id
      result[:image_status] = if parsed_data[:granblue_id].present?
                                queue_image_download(parsed_data[:granblue_id], entity_type)
                              else
                                'no_id'
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

  # Fetches the page from the wiki, following one redirect. A redirect
  # records the page it came from and the page it went to in result.
  # @return [String] the wikitext
  def fetch_wiki_preview_text(wiki_page, result)
    wiki = Granblue::Parsers::Wiki.new
    wiki_text = wiki.fetch(wiki_page)
    redirect_match = wiki_text.match(/#REDIRECT \[\[(.*?)\]\]/)
    return wiki_text unless redirect_match

    redirect_target = redirect_match[1]
    result[:redirected_from] = wiki_page
    result[:wiki_page] = redirect_target
    wiki.fetch(redirect_target)
  end

  # Parse data from wiki text based on entity type
  # @return [Hash, nil] nil for an unknown entity type
  def parse_wiki_preview(wiki_text, entity_type)
    case entity_type
    when :character then Granblue::Parsers::WikiDataParser.parse_character(wiki_text)
    when :weapon then Granblue::Parsers::WikiDataParser.parse_weapon(wiki_text)
    when :summon then Granblue::Parsers::WikiDataParser.parse_summon(wiki_text)
    end
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
