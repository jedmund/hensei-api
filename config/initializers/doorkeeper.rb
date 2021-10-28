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
        User.find_by(email: params[:email]).try(:authenticate, params[:password])
    end

    # Specify what grant flows are enabled in array of Strings. The valid
    # strings and the flows they enable are:
    grant_flows %w(authorization_code client_credentials password)

    skip_client_authentication_for_password_grant true
end