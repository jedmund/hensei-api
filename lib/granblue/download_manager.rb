# frozen_string_literal: true

module Granblue
  module Downloader
    class DownloadManager
      class << self
        def download_for_object(type, granblue_id, test_mode: false, verbose: false, storage: :both)
          downloader_options = {
            test_mode: test_mode,
            verbose: verbose,
            storage: storage
          }

          case type
          when 'character'
            CharacterDownloader.new(granblue_id, **downloader_options).download
          when 'weapon'
            WeaponDownloader.new(granblue_id, **downloader_options).download
          when 'summon'
            SummonDownloader.new(granblue_id, **downloader_options).download
          else
            log_info "Unknown object type: #{type}" if verbose || test_mode
          end
        end
      end
    end
  end
end
