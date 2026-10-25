# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads weapon skill icons from the game CDN in both EN and JA variants.
    #
    # Icons are stored under the CDN's own file name, so the frontend can recreate
    # it from a weapon's element.
    #
    # EN icons come from /assets_en/, JA from /assets/. They are stored under
    # "weapon-skill-icons/en/" and "weapon-skill-icons/ja/".
    #
    # @example
    #   WeaponSkillIconDownloader.new("skill_atk_3_4", storage: :both).download
    class WeaponSkillIconDownloader < BaseDownloader
      SIZES = %w[icon].freeze

      # language => CDN asset-root segment
      LANGUAGES = { 'en' => 'assets_en', 'ja' => 'assets' }.freeze

      CDN_HOST = 'https://prd-game-a-granbluefantasy.akamaized.net'
      ICON_PATH = 'img/sp/ui/icon/skill'

      # Downloads the EN and JA icon.
      # @return [Hash{String=>Hash}] per-language result ({ success:, skipped?:, error? })
      def download(_selected_size = nil)
        log_info("-> #{@id}") if @verbose
        return {} if @test_mode

        LANGUAGES.keys.index_with { |lang| download_one(lang) }
      end

      private

      def download_one(lang)
        filename = "#{@id}.png"
        s3_key = "#{object_type}/#{lang}/#{filename}"
        local_uri = "#{Rails.root}/download/#{object_type}/#{lang}/#{filename}"
        return { success: true, skipped: true } unless should_download?(local_uri, s3_key)

        url = "#{CDN_HOST}/#{LANGUAGES.fetch(lang)}/#{ICON_PATH}/#{@id}.png"
        log_info "\t└ #{lang}: #{url}..."
        case @storage
        when :local then download_to_local(url, local_uri)
        when :s3 then stream_to_s3(url, s3_key)
        when :both then download_to_both(url, local_uri, s3_key)
        end
        { success: true }
      rescue OpenURI::HTTPError => e
        log_info "\t404 returned\t#{lang}/#{@id}"
        { success: false, error: e.message }
      rescue StandardError => e
        log_info "\tError downloading #{lang}/#{@id}: #{e.message}"
        { success: false, error: e.message }
      end

      # @return [String] S3 prefix / local dir name (matches the frontend's
      # icons/weapon-skills bucket and static/images/icons/weapon-skills/).
      def object_type
        'icons/weapon-skills'
      end

      # Create the en/ja subdirectories (base class only knows about sizes).
      def ensure_directories_exist
        return unless store_locally?

        LANGUAGES.each_key do |lang|
          FileUtils.mkdir_p("#{Rails.root}/download/#{object_type}/#{lang}")
        end
      end

      # Required by BaseDownloader's interface; per-language URLs are built in
      # #download_one, so these are only sensible defaults.
      def base_url
        "#{CDN_HOST}/#{LANGUAGES.fetch('en')}/#{ICON_PATH}"
      end

      def directory_for_size(_size)
        nil
      end
    end
  end
end
