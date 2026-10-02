Doorkeeper.configure do
    # Change the ORM that doorkeeper will use (needs plugins)
    orm :active_record

    # Issue access tokens with refresh token (disabled by default)
    use_refresh_token

    # Access token expiration time (default 2 hours).
    # If you want to disable expiration, set this to nil.
    access_token_expires_in 1.month

    # This block will be called to authenticate the resource owner.
    resource_owner_from_credentials do |routes|
        User.find_by(email: params[:email]&.downcase).try(:authenticate, params[:password])
    end

    # Only the password grant is used (the web app and the extension both log
    # in with it). Refresh tokens are enabled by use_refresh_token above, not
    # here. authorization_code and client_credentials stay off: no client uses
    # them, and the authorize page can't render in this API-only app.
    grant_flows %w(password)

    skip_client_authentication_for_password_grant true
end