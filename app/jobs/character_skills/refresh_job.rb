# frozen_string_literal: true

module CharacterSkills
  # Runs a batch refresh (RefreshBatch).
  #   preview: fetches each character in order (≥2s per request, WikiPacer), builds it in
  #            shadow mode, and stores the result and the fetched text per character.
  #            One that fails is marked failed and the rest carry on.
  #   apply:   writes the characters the editor chose from the stored text (Refresh#apply)
  #            and marks the other previewed ones skipped.
  class RefreshJob < ApplicationJob
    queue_as :default

    # Raised by HTTParty when gbf.wiki or gbf-wiki.com can't be reached at all.
    NETWORK_ERRORS = [SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH,
                      OpenSSL::SSL::SSLError, HTTParty::Error].freeze

    def perform(batch_id, action)
      batch = RefreshBatch.find(batch_id)
      return unless batch

      action == 'apply' ? apply(batch) : preview(batch)
    # Not re-raised: a retry would fetch every page again. The editor sees `failed` and can
    # start another refresh.
    rescue StandardError => e
      Rails.logger.error "[CHARACTER_SKILLS] Refresh #{batch_id} (#{action}) failed: #{e.class}: #{e.message}"
      batch&.status!('failed')
    end

    private

    def preview(batch)
      batch.status!('running')
      batch.items.each do |item|
        character = Character.find_by(id: item[:character_id])
        unless character
          next batch.update_item!(item[:character_id], status: 'failed', **failure(ActiveRecord::RecordNotFound.new))
        end

        batch.update_item!(character.id, status: 'fetching')
        refresh = Refresh.new(character)
        sources = refresh.fetch(refetch: true, refetch_jp: batch.refetch_jp)
        result = refresh.preview(sources)
        batch.store_sources(character.id, sources)
        batch.update_item!(character.id, status: 'previewed', refresh: result)
      rescue StandardError => e
        batch.update_item!(item[:character_id], status: 'failed', **failure(e))
      end
      batch.status!(batch.previewed_ids.any? ? 'previewed' : 'failed')
    end

    def apply(batch)
      chosen = batch.apply_ids
      batch.items.each do |item|
        next unless item[:status] == 'previewed'

        if chosen.include?(item[:character_id])
          apply_item(batch, item)
        else
          batch.update_item!(item[:character_id], status: 'skipped')
        end
      end
      batch.status!('applied')
    end

    def apply_item(batch, item)
      batch.update_item!(item[:character_id], status: 'applying')
      character = Character.find(item[:character_id])
      sources = batch.sources(character.id)
      raise Refresh::PreviewExpired, Refresh::EXPIRED_MESSAGE unless sources

      result = Refresh.new(character).apply(sources)
      batch.update_item!(character.id, status: 'applied', refresh: result)
    rescue StandardError => e
      batch.update_item!(item[:character_id], status: 'failed', **failure(e))
    end

    # → { error:, error_code:, error_status: } for an item (D28). error is the English detail;
    # error_code is what the UI localizes:
    #   wiki_fetch_failed: the wiki answered with an error (error_status: its HTTP status) or
    #                      couldn't be reached (error_status: nil);
    #   build_refused:     no wikitext, the build made no skills, or no page / JP title
    #                      (or an undecodable stored one);
    #   preview_expired:   at apply, the previewed text has expired (24 hours);
    #   character_missing: the character was deleted after it was picked;
    #   unexpected:        anything else (a build that raised, a bug).
    def failure(error)
      case error
      when Granblue::WikiError
        { error: "The wiki page #{error.page} could not be fetched (#{error.code || error.message})".squeeze(' '),
          error_code: 'wiki_fetch_failed', error_status: error.code.presence&.to_i }
      when *NETWORK_ERRORS
        { error: "The wiki could not be reached (#{error.class}: #{error.message})",
          error_code: 'wiki_fetch_failed', error_status: nil }
      when Refresh::BuildRefused, Granblue::WikiFetcher::MissingPageError, Granblue::JpWikiTitle::InvalidTitle
        { error: error.message, error_code: 'build_refused', error_status: nil }
      when Refresh::PreviewExpired
        { error: error.message, error_code: 'preview_expired', error_status: nil }
      when ActiveRecord::RecordNotFound
        { error: 'This character no longer exists', error_code: 'character_missing', error_status: nil }
      when Refresh::Error
        { error: error.message, error_code: 'unexpected', error_status: nil }
      else
        Rails.logger.error "[CHARACTER_SKILLS] Refresh item failed: #{error.class}: #{error.message}"
        { error: "#{error.class}: #{error.message}", error_code: 'unexpected', error_status: nil }
      end
    end
  end
end
