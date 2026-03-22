# frozen_string_literal: true

class ProfanityValidator < ActiveModel::EachValidator
  TIERS = %i[moderate strict].freeze

  class << self
    def word_list(*languages, tier: :strict)
      tiers_to_load = case tier
                      when :strict then %i[moderate strict]
                      when :moderate then %i[moderate]
                      else %i[moderate]
                      end

      languages.flat_map do |lang|
        tiers_to_load.flat_map { |t| tier_list(lang, t) }
      end
    end

    def reserved_list
      @reserved_list ||= load_list('config/profanity/reserved.yml')
    end

    def reset!
      @tier_lists = nil
      @reserved_list = nil
    end

    private

    def tier_list(lang, tier)
      @tier_lists ||= {}
      key = :"#{lang}_#{tier}"
      @tier_lists[key] ||= load_list("config/profanity/#{lang}/#{tier}.yml")
    end

    def load_list(path)
      file = Rails.root.join(path)
      return [] unless File.exist?(file)

      (YAML.load_file(file) || []).map { |w| w.to_s.strip.downcase }.compact_blank
    end
  end

  def validate_each(record, attribute, value)
    return if value.blank?

    languages = options.fetch(:languages, [:en])
    tier = options.fetch(:tier, :strict)
    check_reserved = options.fetch(:reserved, false)

    normalized = value.strip.downcase
    segments = normalized.split(/[_\-\s]+/)
    candidates = segments + [normalized]

    words = self.class.word_list(*languages, tier: tier)
    if candidates.any? { |c| words.include?(c) }
      record.errors.add(attribute, options[:message] || :profanity)
      return
    end

    if check_reserved && self.class.reserved_list.include?(normalized)
      record.errors.add(attribute, options[:message] || :reserved)
    end
  end
end
