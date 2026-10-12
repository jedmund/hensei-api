# frozen_string_literal: true

module Api
  module V1
    class GachaController < ApiController
      before_action :computation_limit, only: %i[simulations until_result odds]
      around_action :measure_gacha
      rescue_from GachaSimulation::ValidationError do |error|
        render json: { error: error.message }, status: :unprocessable_entity
      end
      rescue_from GachaSimulation::Unavailable do |error|
        response.set_header('Retry-After', '60')
        render json: { error: error.message }, status: :service_unavailable
      end

      def catalogue
        config = GachaSimulation::Configuration.normalize(params.permit(:mode, :season, :purchase, :banner).to_h)
        snapshot = GachaSimulation::Catalogue.snapshot
        banner = current_banner(config, snapshot['items'])
        items = if banner
                  snapshot['items'].select { |item| banner[:ids].include?(item['granblue_id']) }
                else
                  snapshot['items'].select { |item| GachaSimulation::Configuration.eligible?(item, config) }
                end
        query = params[:q].to_s.downcase.first(100)
        if query.present?
          items = items.select { |item|
            [item['identity'], item['granblue_id'], *item['name'].values, *item['recruits']&.values].compact.any? { |v|
              v.downcase.include?(query)
            }
          }
        end
        modes = GachaSimulation::Configuration::MODES.keys
        modes = [GachaSimulation::Configuration::CURRENT, *modes] if GachaBanner.exists?
        render json: { modes: modes, seasons: GachaSimulation::Configuration::SEASONS.keys,
                       items: items, catalogue_fingerprint: snapshot['fingerprint'], loaded_at: snapshot['loaded_at'],
                       banner: banner&.fetch(:info),
                       label: banner ? "The game's published banner rates" : 'Hypothetical catalogue simulations' }
      end

      def simulations
        input, compiled = prepare
        count = GachaSimulation::Engine.draw_count(input, compiled['config'])
        if count > 10_000
          input['seed'] ||= SecureRandom.hex(16)
          GachaSimulation::Engine.new(compiled, input['seed']) # Validate before accepting a queued job.
          token = GachaSimulation::Jobs.enqueue(compiled, input)
          render json: { token: token, status: 'queued', seed: input['seed'] }, status: :accepted
        else
          render json: GachaSimulation::Engine.new(compiled, input['seed']).draw(count)
        end
      end

      def until_result
        input, compiled = prepare
        render json: GachaSimulation::Engine.new(compiled, input['seed']).target('until', input)
      end

      def odds
        input, compiled = prepare
        render json: GachaSimulation::Engine.new(compiled, input['seed']).target('odds', input)
      end

      def job
        data = GachaSimulation::Jobs.read(params[:token])
        if data
          render json: data.slice('status', 'result', 'error')
        else
          render json: { error: 'Job not found or expired' }, status: :not_found
        end
      end

      private

      # The banner's details and its rate-ups as catalogue identities
      def current_banner(config, items)
        return unless config['mode'] == GachaSimulation::Configuration::CURRENT

        banner = GachaSimulation::Banner.load(config['banner'])
        by_id = items.index_by { |item| item['granblue_id'] }
        rateups = banner.rateups.filter_map do |id, percent|
          { identity: by_id[id]['identity'], percent: percent } if by_id[id]
        end
        { ids: banner.reward_ids.to_set, info: banner.info.merge('rateups' => rateups) }
      end

      def prepare
        if params.key?(:rateups) && !params[:rateups].is_a?(Array)
          raise GachaSimulation::ValidationError, 'Rate-ups must be an array'
        end
        input = params.permit(:mode, :season, :purchase, :banner, :draws, :seed, :target, :copies, :comparison,
                              rateups: %i[identity percent]).to_h
        config = GachaSimulation::Configuration.normalize(input)
        snapshot = GachaSimulation::Catalogue.snapshot
        Rails.logger.info("gacha catalogue_age=#{Time.now.to_i - snapshot['loaded_at']}")
        [input, GachaSimulation::Compiler.new(snapshot, config).compile]
      end

      def computation_limit
        store = Rails.application.config.x.rate_limit_store
        count = store.increment("gacha:computation:#{client_ip}", 1, expires_in: 60)
        raise GachaSimulation::Unavailable, 'Computation limiter unavailable' unless count
        return if count <= ENV.fetch('GACHA_REQUESTS_PER_MINUTE', '60').to_i

        response.set_header('Retry-After', '60')
        render json: { error: 'Gacha computation limit reached; retry in 60 seconds', retry_after: 60 }, status: :too_many_requests
      end

      def measure_gacha
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        yield
      ensure
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        Rails.logger.info("gacha action=#{action_name} duration_ms=#{(duration * 1000).round}")
      end
    end
  end
end
