# frozen_string_literal: true

# A one-time code that lets the browser extension get its own tokens for a
# user who approved it on the site (granblue.team/auth/extension).
#
# The code is bound to the PKCE challenge the extension generated, lives for
# TTL and can be redeemed once. Only its SHA-256 digest is stored; the raw
# code is returned once by .issue and never persisted or logged.
class ExtensionAuthCode < ApplicationRecord
  TTL = 60.seconds
  CHALLENGE_METHOD = 'S256'
  # base64url(SHA-256(verifier)) without padding is always 43 characters.
  CHALLENGE_FORMAT = /\A[A-Za-z0-9_-]{43}\z/
  # RFC 7636 section 4.1.
  VERIFIER_FORMAT = /\A[A-Za-z0-9\-._~]{43,128}\z/
  MAX_CODE_LENGTH = 128

  belongs_to :user

  validates :code_digest, :code_challenge, :expires_at, presence: true
  validates :code_challenge, format: { with: CHALLENGE_FORMAT }

  scope :expired, -> { where(expires_at: ..Time.current) }

  class << self
    def valid_challenge?(challenge, method)
      method == CHALLENGE_METHOD && challenge.is_a?(String) && CHALLENGE_FORMAT.match?(challenge)
    end

    # Creates a code for the user and returns the raw code.
    def issue(user, code_challenge:)
      code = SecureRandom.urlsafe_base64(32)
      create!(user: user, code_digest: digest(code), code_challenge: code_challenge, expires_at: TTL.from_now)
      code
    end

    # Returns the code's user, or nil for an unknown, expired, used or
    # mismatched code. The code is claimed before the verifier is checked, so
    # a wrong verifier also uses it up.
    def redeem(code, code_verifier)
      return nil unless well_formed?(code, code_verifier)

      record = find_by(code_digest: digest(code))
      return nil unless record&.claim!

      record.verifier_matches?(code_verifier) ? record.user : nil
    end

    def digest(code)
      Digest::SHA256.hexdigest(code)
    end

    def challenge_for(verifier)
      Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    end

    private

    def well_formed?(code, code_verifier)
      code.is_a?(String) && code.present? && code.bytesize <= MAX_CODE_LENGTH &&
        code_verifier.is_a?(String) && VERIFIER_FORMAT.match?(code_verifier)
    end
  end

  # Marks the code used in one conditional update, so of two concurrent
  # redemptions only one can succeed. Returns whether this call claimed it.
  def claim!
    now = Time.current
    claimed = self.class.where(id: id, used_at: nil)
                  .where('expires_at > ?', now)
                  .update_all(used_at: now, updated_at: now)
    claimed == 1
  end

  def verifier_matches?(code_verifier)
    ActiveSupport::SecurityUtils.secure_compare(self.class.challenge_for(code_verifier), code_challenge)
  end
end
