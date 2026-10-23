# frozen_string_literal: true

# The conventional n/p/g/k names match the binomial equations used here.
# rubocop:disable Naming/MethodParameterName
module GachaSimulation
  # Counts are integers, including beyond JS's safe range. Only numerical
  # probability evaluation uses Float; compilation and currency use decimals.
  module Probability
    module_function

    def log1p(x)
      return Math.log(1 + x) if x.abs > 1e-4

      (1..12).sum { |k| ((k.odd? ? 1.0 : -1.0) * (x**k)) / k }
    end

    def expm1(x)
      return Math.exp(x) - 1 if x.abs > 1e-4

      term = 1.0
      (1..12).sum { |k| term *= x / k }
    end

    def pmfs(n, p, limit)
      return [1.0] + Array.new(limit, 0.0) if p.zero? || n.zero?
      return Array.new(limit + 1) { |k| k == n ? 1.0 : 0.0 } if p == 1

      log_probability = n * log1p(-p)
      result = [Math.exp(log_probability)]
      1.upto(limit) do |k|
        if k > n
          result << 0.0
        else
          log_probability += Math.log(n - k + 1) - Math.log(k) + Math.log(p) - log1p(-p)
          result << Math.exp(log_probability)
        end
      end
      result
    end

    def tail(n, p, k, masses = pmfs(n, p, k))
      return 1.0 if k <= 0
      return 0.0 if k > n || p.zero?
      return 1.0 if p == 1
      return (1 - masses.first(k).sum).clamp(0.0, 1.0) if k <= n * p

      # Sum the upper tail directly to avoid cancellation for rare outcomes.
      term = masses[k]
      total = term
      i = k
      while i < n && term.positive?
        term *= (n - i).to_f / (i + 1) * p / (1 - p)
        total += term
        i += 1
        break if term < total * 1e-15
      end
      [total, 1.0].min
    end

    def odds(n, p, g, copies, purchase, comparison)
      guaranteed = purchase == 'ten' ? n / 10 : 0
      ordinary = n - guaranteed
      return binomial(n, p, copies, comparison) if guaranteed.zero? || p == g

      a = pmfs(ordinary, p, copies)
      b = pmfs(guaranteed, g, copies)
      return (0..copies).sum { |j| b[j] * a[copies - j] } if comparison == 'exactly'

      tails = Array.new(copies + 1, 0.0)
      tails[copies] = tail(ordinary, p, copies, a)
      (copies - 1).downto(0) { |k| tails[k] = [1.0, tails[k + 1] + a[k]].min }
      [1.0, tail(guaranteed, g, copies, b) + (0...copies).sum { |j| b[j] * tails[copies - j] }].min
    end

    def binomial(n, p, copies, comparison)
      masses = pmfs(n, p, copies)
      comparison == 'exactly' ? masses[copies] : tail(n, p, copies, masses)
    end

    def threshold(p, g, copies, purchase, level)
      step = purchase == 'ten' ? 10 : 1
      limit = 1_000_000_000_000 / step
      low = 0
      high = 1
      high = [high * 2, limit].min while high < limit && odds(high * step, p, g, copies, purchase, 'at_least') < level
      return nil if odds(high * step, p, g, copies, purchase, 'at_least') < level

      while high - low > 1
        middle = (high + low) / 2
        if odds(middle * step, p, g, copies, purchase, 'at_least') >= level
          high = middle
        else
          low = middle
        end
      end
      (high * step).to_s
    end

    def geometric(random, log_failure)
      return 1 if log_failure == -Float::INFINITY

      (BigDecimal(log1p(-random.rand).to_s) / BigDecimal(log_failure.to_s)).floor + 1
    end

    def waiting(random, p, g, copies, purchase)
      if purchase == 'singles'
        log_failure = p == 1 ? -Float::INFINITY : log1p(-p)
        return { 'draws' => copies.times.sum { geometric(random, log_failure) }.to_s, 'copies' => copies.to_s }
      end
      log_failure = p == 1 || g == 1 ? -Float::INFINITY : (9 * log1p(-p)) + log1p(-g)
      success = -expm1(log_failure)
      ordinary = pmfs(9, p, 9)
      weights = (1..10).map { |k| (((ordinary[k] || 0) * (1 - g)) + (ordinary[k - 1] * g)) / success }
      blocks = 0
      count = 0
      while count < copies
        blocks += geometric(random, log_failure)
        value = random.rand
        cumulative = 0.0
        index = weights.index { |weight|
          cumulative += weight
          value < cumulative
        } || 9
        count += index + 1
      end
      { 'draws' => (blocks * 10).to_s, 'copies' => count.to_s }
    end
  end
end

# rubocop:enable Naming/MethodParameterName
