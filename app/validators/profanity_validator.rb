# frozen_string_literal: true

class ProfanityValidator < ActiveModel::EachValidator
  class << self
    def word_list(*languages)
      @word_lists ||= {}
      languages.flat_map do |lang|
        @word_lists[lang] ||= load_list("config/profanity/#{lang}.yml")
      end
    end

    def reserved_list
      @reserved_list ||= load_list('config/profanity/reserved.yml')
    end

    def reset!
      @word_lists = nil
      @reserved_list = nil
    end

    private

    def load_list(path)
      file = Rails.root.join(path)
      return [] unless File.exist?(file)

      (YAML.load_file(file) || []).map { |w| w.to_s.strip.downcase }.compact_blank
    end
  end

  def validate_each(record, attribute, value)
    return if value.blank?

    languages = options.fetch(:languages, [:en])
    check_reserved = options.fetch(:reserved, false)

    normalized = value.strip.downcase
    segments = normalized.split(/[_\-\s]+/)
    candidates = segments + [normalized]

    words = self.class.word_list(*languages)
    if candidates.any? { |c| words.include?(c) }
      record.errors.add(attribute, options[:message] || :profanity)
      return
    end

    if check_reserved && self.class.reserved_list.include?(normalized)
      record.errors.add(attribute, options[:message] || :reserved)
    end
  end
end
