# frozen_string_literal: true

module Granblue
  module Downloader
    class DownloadManager
      class << self
        def download_for_object(type, granblue_id, test_mode: false, verbose: false, storage: :both)
          @test_mode = test_mode
          @verbose = verbose
          @storage = storage

          case type
          when 'character'
            download_character(granblue_id)
          when 'weapon'
            download_weapon(granblue_id)
          when 'summon'
            download_summon(granblue_id)
          else
            log_info "Unknown object type: #{type}"
          end
        end

        private

        def download_character(id)
          character = Character.find_by(granblue_id: id)
          return unless character

          downloader_options = {
            test_mode: @test_mode,
            verbose: @verbose,
            storage: @storage
          }

          %W[#{id}_01 #{id}_02].each do |variant_id|
            CharacterDownloader.new(variant_id, **downloader_options).download
          end

          CharacterDownloader.new("#{id}_03", **downloader_options).download if character.flb
          CharacterDownloader.new("#{id}_04", **downloader_options).download if character.ulb
        end

        def download_weapon(id)
          weapon = Weapon.find_by(granblue_id: id)
          return unless weapon

          downloader_options = {
            test_mode: @test_mode,
            verbose: @verbose,
            storage: @storage
          }

          WeaponDownloader.new(id, **downloader_options).download

          return unless weapon.transcendence

          WeaponDownloader.new("#{id}_02", **downloader_options).download
          WeaponDownloader.new("#{id}_03", **downloader_options).download

        end

        def download_summon(id)
          summon = Summon.find_by(granblue_id: id)
          return unless summon

          downloader_options = {
            test_mode: @test_mode,
            verbose: @verbose,
            storage: @storage
          }

          SummonDownloader.new(id, **downloader_options).download
          SummonDownloader.new("#{id}_02", **downloader_options).download if summon.ulb

          return unless summon.transcendence
          
          SummonDownloader.new("#{id}_03", **downloader_options).download
          SummonDownloader.new("#{id}_04", **downloader_options).download

        end

        def log_info(message)
          puts message if @verbose || @test_mode
        end
      end
    end
  end
end
