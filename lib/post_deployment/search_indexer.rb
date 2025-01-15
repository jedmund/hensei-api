# frozen_string_literal: true

require_relative '../logging_helper'

module PostDeployment
  class SearchIndexer
    include LoggingHelper

    def initialize(test_mode:, verbose:)
      @test_mode = test_mode
      @verbose = verbose
    end

    def rebuild_all
      log_header 'Rebuilding search indices...', '-'
      puts "\n"

      ensure_models_loaded
      rebuild_indices
    end

    private

    def ensure_models_loaded
      Rails.application.eager_load! if Rails.application.config.eager_load
    end

    def rebuild_indices
      searchable_models.each do |model_name|
        begin
          model = model_name.constantize
          rebuild_index_for(model)
        rescue NameError => e
          log_error("Could not load model: #{model_name}")
          log_error(e.message) if @verbose
        end
      end
    end

    def rebuild_index_for(model)
      if @test_mode
        log_step "Would rebuild search index for #{model.name}"
      else
        log_verbose "• #{model.name}... "
        PgSearch::Multisearch.rebuild(model)
        log_verbose "✅ done!\n"
      end
    rescue StandardError => e
      log_error("Failed to rebuild index for #{model.name}: #{e.message}")
      log_error(e.backtrace.take(5).join("\n")) if @verbose
    end

    def searchable_models
      %w[Character Summon Weapon Job]
    end

    def log_error(message)
      puts "❌ #{message}"
    end
  end
end
