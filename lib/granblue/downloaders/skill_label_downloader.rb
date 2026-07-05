# frozen_string_literal: true

module Granblue
  module Downloaders
    # Downloads the in-game weapon-skill label badges (the "Weapon Skill Boosts"
    # panel tags) from the game CDN in both EN and JA variants.
    #
    # The badge is fetched by its GAME filename (e.g. "01_icon_might_01.png")
    # but stored under OUR label slug (e.g. "might.png") so the frontend can
    # build URLs straight from a panel line's label_slug.
    #
    # Stored under "icons/skill-labels/en/" and "icons/skill-labels/ja/".
    #
    # @example
    #   SkillLabelDownloader.new("might", source_filename: "01_icon_might_01.png", storage: :s3).download
    class SkillLabelDownloader < BaseDownloader
      SIZES = %w[icon].freeze

      # language => CDN asset-root segment
      LANGUAGES = { 'en' => 'assets_en', 'ja' => 'assets' }.freeze

      CDN_HOST = 'https://prd-game-a-granbluefantasy.akamaized.net'
      LABEL_PATH = 'img/sp/ui/icon/weapon_skill_label'

      # @param id [String] our label slug — the stored filename
      # @param source_filename [String] the game's filename on the CDN
      def initialize(id, source_filename:, **)
        @source_filename = source_filename
        super(id, **)
      end

      # Downloads the EN and JA badge.
      # @return [Hash{String=>Hash}] per-language result ({ success:, skipped?:, error? })
      def download(_selected_size = nil)
        log_info("-> #{@id} (source #{@source_filename})") if @verbose
        return {} if @test_mode

        LANGUAGES.keys.index_with { |lang| download_one(lang) }
      end

      private

      def download_one(lang)
        filename = "#{@id}.png"
        s3_key = "#{object_type}/#{lang}/#{filename}"
        local_uri = "#{Rails.root}/download/#{object_type}/#{lang}/#{filename}"
        return { success: true, skipped: true } unless should_download?(local_uri, s3_key)

        url = "#{CDN_HOST}/#{LANGUAGES.fetch(lang)}/#{LABEL_PATH}/#{@source_filename}"
        log_info "\t└ #{lang}: #{url}..."
        case @storage
        when :local then download_to_local(url, local_uri)
        when :s3 then stream_to_s3(url, s3_key)
        when :both then download_to_both(url, local_uri, s3_key)
        end
        { success: true }
      rescue OpenURI::HTTPError => e
        log_info "\t404 returned\t#{lang}/#{@source_filename}"
        { success: false, error: e.message }
      rescue StandardError => e
        log_info "\tError downloading #{lang}/#{@source_filename}: #{e.message}"
        { success: false, error: e.message }
      end

      # @return [String] S3 prefix / local dir name (matches the frontend's
      # icons/skill-labels bucket).
      def object_type
        'icons/skill-labels'
      end

      # Satisfies the base class contract; per-language URLs are built in
      # download_one.
      def base_url
        "#{CDN_HOST}/#{LANGUAGES.fetch('en')}/#{LABEL_PATH}"
      end

      # Create the en/ja subdirectories (base class only knows about sizes).
      def ensure_directories_exist
        return unless store_locally?

        LANGUAGES.each_key do |lang|
          FileUtils.mkdir_p("#{Rails.root}/download/#{object_type}/#{lang}")
        end
      end
    end
  end
end
