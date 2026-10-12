# frozen_string_literal: true

require 'sidekiq/api'
module GachaSimulation
  class Jobs
    QUEUE = 'simulations'

    def self.enqueue(compiled, input)
      token = SecureRandom.hex(24)
      data = { 'status' => 'queued', 'compiled' => compiled, 'input' => input, 'created_at' => Time.now.to_i }
      Sidekiq.redis { |redis| redis.set("gacha:job:#{token}", JSON.generate(data), ex: 3600) }
      SimulationJob.perform_async(token)
      token
    rescue StandardError
      raise Unavailable, 'Simulation queue temporarily unavailable'
    end

    # Runs waiting in the queue or being worked on
    def self.in_flight
      queued = Sidekiq::Queue.new(QUEUE).size
      running = Sidekiq::WorkSet.new.count { |_process, _thread, work| work.queue == QUEUE }
      queued + running
    rescue StandardError
      raise Unavailable, 'Simulation queue temporarily unavailable'
    end

    def self.read(token)
      return nil unless token.to_s.match?(/\A[0-9a-f]{48}\z/)

      value = Sidekiq.redis { |redis| redis.get("gacha:job:#{token}") }
      value && JSON.parse(value)
    end

    def self.finish(token, values)
      # Keep the original one-hour deadline; never resurrect an expired job.
      Sidekiq.redis { |redis| redis.set("gacha:job:#{token}", JSON.generate(values), xx: true, keepttl: true) }
    end
  end
end
