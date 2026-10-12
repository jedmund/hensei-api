# frozen_string_literal: true

module Api
  module V1
    class GachaController < ApiController
      # Draws above this run in the background
      QUEUED_ABOVE = 10_000

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
        if count > QUEUED_ABOVE
          input['seed'] ||= SecureRandom.hex(16)
          GachaSimulation::Engine.new(compiled, input['seed']) # Validate before accepting a queued job.
          return if queued_run_limited?

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

      # Every Draw, Until and Odds request, per visitor
      def computation_limit
        return if limit_reached?('computation', ENV.fetch('GACHA_REQUESTS_PER_MINUTE', '60').to_i, 1.minute,
                                 'Too many draws; try again in a minute')

        limit_reached?('computation-hour', ENV.fetch('GACHA_REQUESTS_PER_HOUR', '600').to_i, 1.hour,
                       'Too many draws this hour; try again later')
        nil
      end

      # Draws too large to answer directly run in the background and keep
      # their result for an hour, so they're limited separately: per visitor,
      # and in total across the site. Returns true once it has responded.
      def queued_run_limited?
        if GachaSimulation::Jobs.in_flight >= ENV.fetch('GACHA_QUEUED_RUNS_MAX', '20').to_i
          raise GachaSimulation::Unavailable, 'The simulator is busy; try again shortly'
        end

        limit_reached?('queued', ENV.fetch('GACHA_QUEUED_RUNS_PER_MINUTE', '10').to_i, 1.minute,
                       'Too many large draws; try again in a minute') ||
          limit_reached?('queued-hour', ENV.fetch('GACHA_QUEUED_RUNS_PER_HOUR', '50').to_i, 1.hour,
                         'Too many large draws this hour; try again later')
      end

      # Counts this request against a per-visitor limit, and responds with a
      # 429 when it's over. Refuses the request when the counter is unreachable.
      def limit_reached?(name, limit, period, message)
        count = Rails.application.config.x.rate_limit_store
                     .increment("gacha:#{name}:#{client_ip}", 1, expires_in: period)
        raise GachaSimulation::Unavailable, 'Computation limiter unavailable' unless count
        return false if count <= limit

        response.set_header('Retry-After', period.to_i.to_s)
        render json: { error: message, retry_after: period.to_i }, status: :too_many_requests
        true
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
