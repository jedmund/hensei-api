# Be sure to restart your server when you modify this file.

# Configure parameters to be filtered from the log file. Use this to limit dissemination of
# sensitive information. See the ActiveSupport::ParameterFilter documentation for supported
# notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  # Extension login: the one-time code and its PKCE verifier.
  /\Acode\z/, :code_verifier,
  # Evoking Solomonis imports: the player's user ID in a party deck
  # (`solomonis.deck` or `solomonis.current_setup`, also under the wrapped
  # `import` key).
  /(\A|\.)solomonis\.(deck|current_setup)\.deck\.pc\.param\.id\z/
]
