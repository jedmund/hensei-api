# frozen_string_literal: true

##
# Singleton config row for the difficulty scoring system.
# Stores the ruleset_version counter, which is bumped any time a Difficulty,
# DifficultyRule, or DifficultyComponent is saved or destroyed. The counter is
# used to invalidate parties whose stored difficulty was computed under an older
# ruleset.
class DifficultyConfig < ApplicationRecord
  def self.instance
    first || create!(ruleset_version: 1)
  rescue ActiveRecord::RecordNotUnique
    # Two callers raced past the `first` check; one inserted, one lost the
    # unique-index check. Re-read the winning row.
    first
  end

  def self.current_version
    instance.ruleset_version
  end

  def self.bump_version!
    record = instance
    record.with_lock do
      record.update_column(:ruleset_version, record.ruleset_version + 1)
    end
    record.ruleset_version
  end
end
