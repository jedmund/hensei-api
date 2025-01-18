class AwsService
  attr_reader :s3_client, :bucket

  class ConfigurationError < StandardError; end

  def initialize
    Rails.logger.info "Environment: #{Rails.env}"

    # Try different methods of getting credentials
    creds = get_credentials
    Rails.logger.info "Credentials source: #{creds[:source]}"

    @s3_client = Aws::S3::Client.new(
      region: creds[:region],
      access_key_id: creds[:access_key_id],
      secret_access_key: creds[:secret_access_key]
    )
    @bucket = creds[:bucket_name]
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
      Rails.logger.info "Using Rails credentials"
      return rails_creds.merge(source: 'rails_credentials')
    end

    # Try string keys
    rails_creds = Rails.application.credentials.dig('aws')
    if rails_creds&.dig('access_key_id')
      Rails.logger.info "Using Rails credentials (string keys)"
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
      Rails.logger.info "Using environment variables"
      return {
        region: ENV['AWS_REGION'],
        access_key_id: ENV['AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['AWS_SECRET_ACCESS_KEY'],
        bucket_name: ENV['AWS_BUCKET_NAME'],
        source: 'environment'
      }
    end

    # Try alternate environment variable names
    if ENV['RAILS_AWS_ACCESS_KEY_ID']
      Rails.logger.info "Using Rails-prefixed environment variables"
      return {
        region: ENV['RAILS_AWS_REGION'],
        access_key_id: ENV['RAILS_AWS_ACCESS_KEY_ID'],
        secret_access_key: ENV['RAILS_AWS_SECRET_ACCESS_KEY'],
        bucket_name: ENV['RAILS_AWS_BUCKET_NAME'],
        source: 'rails_environment'
      }
    end

    validate_credentials = ->(creds, source) {
      missing = []
      %i[region access_key_id secret_access_key bucket_name].each do |key|
        missing << key unless creds[key].present?
      end
      raise ConfigurationError, "Missing AWS credentials from #{source}: #{missing.join(', ')}" if missing.any?
    }

    raise ConfigurationError, "No AWS credentials found in any location"
  end
end
