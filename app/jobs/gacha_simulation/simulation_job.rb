# frozen_string_literal: true

module GachaSimulation
  class SimulationJob
    include Sidekiq::Job

    sidekiq_options retry: false

    def perform(token)
      data = Jobs.read(token)
      return unless data

      Jobs.finish(token, data.merge('status' => 'running'))
      input = data.fetch('input')
      compiled = data.fetch('compiled')
      result = Engine.new(compiled, input['seed']).draw(Engine.draw_count(input, compiled['config']))
      Jobs.finish(token, data.merge('status' => 'complete', 'result' => result))
    rescue StandardError => e
      Rails.logger.error("gacha simulation job failed: #{e.class}")
      Jobs.finish(token, { 'status' => 'failed', 'error' => 'Simulation failed; please retry' })
    end
  end
end
