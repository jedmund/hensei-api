# frozen_string_literal: true

# This custom matcher checks that a model's errors on a given attribute include a specific phrase.
RSpec::Matchers.define :have_error_on do |attribute, expected_phrase|
  match do |model|
    model.valid? && model.errors[attribute].any? { |msg| msg.include?(expected_phrase) }
  end

  failure_message do |model|
    "expected errors on #{attribute} to include '#{expected_phrase}', but got: #{model.errors[attribute].join(', ')}"
  end
end
