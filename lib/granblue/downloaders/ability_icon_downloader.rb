# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads character ability icon images from the game server. The icon stem
    # ("{ability_id}_{N}", e.g. "625_4", where N is the border color) is both the
    # source filename and our storage key — there is no separate slug.
    #
    # @example Download one icon to S3
    #   AbilityIconDownloader.new("625_4", storage: :s3).download
    #
    # @note Single PNG per stem; stored under the "ability-icons/" prefix.
    class AbilityIconDownloader < BaseDownloader
      # Ability icons have only one size.
      SIZES = %w[icon].freeze

      # Downloads the icon for an ability stem.
      # @return [Hash] result with :success (and :skipped / :error) keys
      def download(_selected_size = nil)
        log_info("-> #{@id}") if @verbose
        return { success: false } if @test_mode

        filename = "#{@id}.png"
        s3_key = build_s3_key('icon', filename)
        download_uri = "#{download_path('icon')}/#{filename}"
        return { success: true, skipped: true } unless should_download?(download_uri, s3_key)

        url = build_url('icon')
        log_info "\t└ #{url}..."
        case @storage
        when :local then download_to_local(url, download_uri)
        when :s3 then stream_to_s3(url, s3_key)
        when :both then download_to_both(url, download_uri, s3_key)
        end
        { success: true }
      rescue OpenURI::HTTPError => e
        log_info "\t404 returned\t#{@id}"
        { success: false, error: e.message }
      rescue StandardError => e
        log_info "\tError downloading #{@id}: #{e.message}"
        { success: false, error: e.message }
      end

      private

      # @return [String] S3 prefix / local dir name
      def object_type
        'ability-icons'
      end

      # Stem is the storage key; no size subdirectory.
      def build_s3_key(_size, filename)
        "#{object_type}/#{filename}"
      end

      def download_path(_size)
        "#{Rails.root}/download/#{object_type}"
      end

      def base_url
        'https://prd-game-a-granbluefantasy.akamaized.net/assets_en/img/sp/ui/icon/ability/m'
      end

      def directory_for_size(_size)
        nil
      end

      def build_url(_size)
        "#{base_url}/#{@id}.png"
      end
    end
  end
end
