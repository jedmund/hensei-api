# frozen_string_literal: true

module Granblue
  # Validates the grid damage calculator against the checked-in in-game panel
  # references (data/panel_references/*.json). Shared by the validate_panel
  # rake task and the admin validation endpoint — any change to weapon-skill
  # data should leave every golden panel green.
  class PanelValidator
    Result = Struct.new(:party, :captured_on, :ok, :mismatches, keyword_init: true)

    def self.run(party: nil)
      refs = Rails.root.glob('data/panel_references/*.json')
      refs.select! { |f| f.basename('.json').to_s == party } if party
      refs.map { |f| new(JSON.parse(File.read(f))).validate }
    end

    def initialize(reference)
      @ref = reference
    end

    def validate
      party = Party.find_by(shortcode: @ref.fetch('party'))
      unless party
        return Result.new(party: @ref['party'], captured_on: @ref['captured_on'], ok: false,
                          mismatches: [{ label: 'party', ours: nil, expected: 'missing from this database' }])
      end

      state = @ref.fetch('state', {}).symbolize_keys
      agg = GridDamage::Calculator.boost_list(party, state: state)
      enh = GridDamage::Calculator.send(:enhancements, party, agg)

      mismatches = []
      @ref.fetch('enhancements', {}).each do |frame, expected|
        check(mismatches, "#{frame.capitalize} Enh", enh[frame.to_sym], expected)
      end
      @ref.fetch('lines').each do |line|
        result = agg[line.fetch('boost')]
        ours = if line['series']
                 result&.by_series&.dig(line['series'])&.to_f # rubocop:disable Style/SafeNavigationChainLength
               else
                 result&.total&.to_f
               end
        check(mismatches, line.fetch('label'), ours, line.fetch('value').to_f)
        next if line['capped'].nil?

        # capped:true = the game renders the line orange (at its display cap)
        ours_capped = result ? result.capped == true : false
        unless ours_capped == line['capped']
          mismatches << { label: "#{line.fetch('label')} capped", ours: ours_capped, expected: line['capped'] }
        end
      end
      # Boosts the game does NOT show (e.g. a phantom overskill line) must stay absent.
      Array(@ref['absent']).each do |key|
        total = agg[key]&.total.to_f
        mismatches << { label: "#{key} (must be absent)", ours: total, expected: nil } if total.positive?
      end

      Result.new(party: @ref['party'], captured_on: @ref['captured_on'],
                 ok: mismatches.empty?, mismatches: mismatches)
    end

    private

    # The panel floors displayed integers (HP 249.8 shows 249) and rounds decimals to
    # two places, so an integer reference matches when our floored value equals it;
    # decimal references must match to half a display cent (plus float headroom).
    def value_matches?(ours, ref)
      return false if ours.nil?

      (ours - ref).abs <= 0.00501 || (ref == ref.floor && ours.floor == ref)
    end

    def check(mismatches, label, ours, expected)
      return if value_matches?(ours, expected)

      mismatches << { label: label, ours: ours&.round(2), expected: expected }
    end
  end
end
