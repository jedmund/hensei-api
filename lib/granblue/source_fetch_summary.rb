# frozen_string_literal: true

module Granblue
  # The tally a source fetch task prints at the end (fetch_wiki_data, download_jp_wiki,
  # fetch_game_data): how many rows were fetched, and of those how many came back with
  # the same text as stored (unchanged) or different text (changed); how many were
  # skipped and why; and the errors. The changed rows' granblue_ids are the ones a
  # follow-up build has to look at.
  class SourceFetchSummary
    Error = Struct.new(:granblue_id, :label, :message)

    attr_reader :task, :unchanged, :skips, :errors

    def initialize(task)
      @task = task
      @unchanged = 0
      @changed = []
      @skips = Hash.new(0)
      @errors = []
    end

    # A row whose source was fetched and stored. before/after are the stored value
    # before the fetch and the fetched one.
    def fetched!(granblue_id, before:, after:)
      if before == after
        @unchanged += 1
      else
        @changed << granblue_id.to_s
      end
    end

    def skipped!(reason)
      @skips[reason.to_s] += 1
    end

    def error!(granblue_id, message, label: nil)
      @errors << Error.new(granblue_id.to_s, label, message.to_s)
    end

    def changed = @changed.size
    def fetched = unchanged + changed
    def skipped = skips.values.sum

    # Distinct granblue_ids whose source changed (a style row and its base share one), sorted.
    def changed_ids = @changed.uniq.sort

    def line
      skip_detail = skips.empty? ? '' : " (#{skips.sort.map { |reason, n| "#{reason}: #{n}" }.join(', ')})"
      "#{task}: fetched #{fetched} (unchanged #{unchanged}, changed #{changed}), " \
        "skipped #{skipped}#{skip_detail}, errors #{errors.size}"
    end

    def print(io = $stdout)
      io.puts
      io.puts line
      io.puts "Changed (#{changed_ids.size}): #{changed_ids.join(',')}" if changed_ids.any?
      errors.each do |error|
        io.puts "  error #{error.granblue_id}#{" (#{error.label})" if error.label}: #{error.message}"
      end
    end

    # One granblue_id per line.
    def write_changed(path)
      FileUtils.mkdir_p(File.dirname(path.to_s))
      File.write(path, changed_ids.map { |id| "#{id}\n" }.join)
    end
  end
end
