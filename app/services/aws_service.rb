class AwsService
  attr_reader :s3_client, :bucket

  class ConfigurationError < StandardError; end

  # Used when no bucket/region is configured (local development with `aws login`).
  DEFAULT_BUCKET = 'siero-img'.freeze
  DEFAULT_REGION = 'us-west-2'.freeze

  def initialize
    Rails.logger.debug "Environment: #{Rails.env}"

    # Static keys (Rails credentials or env vars) win; production uses them.
    creds = get_credentials
    if creds
      Rails.logger.debug "Credentials source: #{creds[:source]}"
      @s3_client = Aws::S3::Client.new(
        region: creds[:region],
        access_key_id: creds[:access_key_id],
        secret_access_key: creds[:secret_access_key],
        session_token: creds[:session_token]
      )
      @bucket = creds[:bucket_name].presence || DEFAULT_BUCKET
    else
      # Otherwise let the SDK's default chain find credentials: an `aws login` or
      # SSO session, AWS_* variables with a session token, or an instance role.
      @s3_client = Aws::S3::Client.new(region: default_region)
      unless @s3_client.config.credentials&.set?
        raise ConfigurationError, 'No AWS credentials found in any location ' \
                                  '(Rails credentials, AWS_* environment variables, or an AWS CLI session ' \
                                  'such as `aws login`)'
      end

      Rails.logger.debug "Credentials source: #{@s3_client.config.credentials.class.name}"
      @bucket = ENV['AWS_BUCKET_NAME'].presence || DEFAULT_BUCKET
    end
  rescue KeyError => e
    raise ConfigurationError, "Missing AWS credential: #{e.message}"
  end

  def upload_stream(io, key)
    @s3_client.put_object(
      bucket: @bucket,
      key: key,
      body: io
    )
  end

  def file_exists?(key)
    @s3_client.head_object(
      bucket: @bucket,
      key: key
    )
    true
  rescue Aws::S3::Errors::NotFound
    false
  end

  private

  def get_credentials
    # Try Rails credentials first
    rails_creds = Rails.application.credentials.dig(:aws)
    if rails_creds&.dig(:access_key_id)
      Rails.logger.debug "Using Rails credentials"
      return rails_creds.merge(source: 'rails_credentials')
    end

    # Try string keys
    rails_creds = Rails.application.credentials.dig('aws')
    if rails_creds&.dig('access_key_id')
      Rails.logger.debug "Using Rails credentials (string keys)"
      return {
        region: rails_creds['region'],
        access_key_id: rails_creds['access_key_id'],
        secret_access_key: rails_creds['secret_access_key'],
        bucket_name: rails_creds['bucket_name'],
        source: 'rails_credentials_string'
      }
    end

    # Try environment variables
    if ENV['AWS_ACCESS_KEY_ID']
      Rails.logger.debug "Using environment variables"
      return {
        region: ENV['AWS_REGION'],
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
        session_token: ENV['AWS_SESSION_TOKEN'].presence,
        bucket_name: ENV['AWS_BUCKET_NAME'],
        source: 'environment'
      }
    end

    # Try alternate environment variable names
    if ENV['RAILS_AWS_ACCESS_KEY_ID']
      Rails.logger.debug "Using Rails-prefixed environment variables"
      return {
        region: ENV['RAILS_AWS_REGION'],
        access_key_id: ENV['RAILS_AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['RAILS_AWS_SECRET_ACCESS_KEY'],
        bucket_name: ENV['RAILS_AWS_BUCKET_NAME'],
        source: 'rails_environment'
      }
    end

    nil
  end

  def default_region
    ENV['AWS_REGION'].presence || Aws.shared_config.region || DEFAULT_REGION
  end
end
