# frozen_string_literal: true

module SocialAuth
  # Suggests an available username from what the provider calls the user, to
  # pre-fill the username step. Returns nil when nothing usable comes out.
  module UsernameSuggester
    ATTEMPTS = 3

    class << self
      def call(hint)
        base = hint.to_s.gsub(/[^a-zA-Z0-9_-]/, '').first(26)
        return nil if base.length < 3

        candidates = [base] + Array.new(ATTEMPTS) { "#{base.first(22)}#{SecureRandom.random_number(1000..9999)}" }
        candidates.find { |candidate| available?(candidate) }
      end

      private

      def available?(username)
        user = User.new(username: username)
        user.valid?
        user.errors[:username].empty?
      end
    end
  end
end
