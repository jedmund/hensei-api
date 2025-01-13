# frozen_string_literal: true

require 'aws-sdk-s3'

class AwsService
  class ConfigurationError < StandardError; end

  def initialize
    validate_credentials!

    @s3_client = Aws::S3::Client.new(
      region: Rails.application.credentials.dig(:aws, :region),
      access_key_id: Rails.application.credentials.dig(:aws, :access_key_id),
      secret_access_key: Rails.application.credentials.dig(:aws, :secret_access_key)
    )
    @bucket = Rails.application.credentials.dig(:aws, :bucket_name)
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

  def credentials
    @credentials ||= begin
                       creds = Rails.application.credentials[:aws]
                       raise ConfigurationError, 'AWS credentials not found' unless creds

                       {
                         region: creds[:region],
                         access_key_id: creds[:access_key_id],
                         secret_access_key: creds[:secret_access_key],
                         bucket_name: creds[:bucket_name]
                       }
                     end
  end

  def validate_credentials!
    missing = []
    creds = Rails.application.credentials[:aws]

    %i[region access_key_id secret_access_key bucket_name].each do |key|
      missing << key unless creds&.dig(key)
    end

    return unless missing.any?

    raise ConfigurationError, "Missing AWS credentials: #{missing.join(', ')}"
  end
end
