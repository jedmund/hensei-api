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
        next batch.update_item!(item[:character_id], status: 'failed', error: 'This character no longer exists') unless character

        batch.update_item!(character.id, status: 'fetching')
        refresh = Refresh.new(character)
        sources = refresh.fetch(refetch: true, refetch_jp: batch.refetch_jp)
        result = refresh.preview(sources)
        batch.store_sources(character.id, sources)
        batch.update_item!(character.id, status: 'previewed', refresh: result)
      rescue StandardError => e
        batch.update_item!(item[:character_id], status: 'failed', error: item_error(e))
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
      batch.update_item!(item[:character_id], status: 'failed', error: item_error(e))
    end

    def item_error(error)
      case error
      when Granblue::WikiError
        "The wiki page #{error.page} could not be fetched (#{error.code || error.message})".squeeze(' ')
      when Refresh::Error, Granblue::WikiFetcher::MissingPageError
        error.message
      else
        Rails.logger.error "[CHARACTER_SKILLS] Refresh item failed: #{error.class}: #{error.message}"
        "#{error.class}: #{error.message}"
      end
    end
  end
end
