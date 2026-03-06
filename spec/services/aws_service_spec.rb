# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AwsService do
  let(:s3_client_double) { double('Aws::S3::Client') }

  before do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client_double)
    allow(Rails.logger).to receive(:debug)
  end

  describe '#initialize' do
    context 'with Rails credentials (symbol keys)' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:aws).and_return({
          region: 'us-east-1',
          access_key_id: 'AKIA_TEST',
          secret_access_key: 'secret',
          bucket_name: 'test-bucket'
        })
      end

      it 'initializes successfully' do
        service = described_class.new
        expect(service.bucket).to eq('test-bucket')
      end

      it 'creates S3 client with credentials' do
        described_class.new
        expect(Aws::S3::Client).to have_received(:new).with(hash_including(
          region: 'us-east-1',
          access_key_id: 'AKIA_TEST'
        ))
      end
    end

    context 'with Rails credentials (string keys)' do
      before do
        allow(Rails.application.credentials).to receive(:dig).with(:aws).and_return(nil)
        allow(Rails.application.credentials).to receive(:dig).with('aws').and_return({
          'region' => 'eu-west-1',
          'access_key_id' => 'AKIA_STRING',
          'secret_access_key' => 'secret2',
          'bucket_name' => 'string-bucket'
        })
      end

      it 'initializes with string key credentials' do
        service = described_class.new
        expect(service.bucket).to eq('string-bucket')
      end
    end

    context 'with environment variables' do
      before do
        allow(Rails.application.credentials).to receive(:dig).and_return(nil)
        stub_const('ENV', ENV.to_h.merge(
          'AWS_ACCESS_KEY_ID' => 'AKIA_ENV',
          'AWS_SECRET_ACCESS_KEY' => 'env_secret',
          'AWS_REGION' => 'ap-southeast-1',
          'AWS_BUCKET_NAME' => 'env-bucket'
        ))
      end

      it 'initializes with env vars' do
        service = described_class.new
        expect(service.bucket).to eq('env-bucket')
      end
    end

    context 'with no credentials' do
      before do
        allow(Rails.application.credentials).to receive(:dig).and_return(nil)
        stub_const('ENV', {})
      end

      it 'raises ConfigurationError' do
        expect { described_class.new }.to raise_error(AwsService::ConfigurationError, /No AWS credentials/)
      end
    end
  end

  describe '#upload_stream' do
    let(:service) do
      allow(Rails.application.credentials).to receive(:dig).with(:aws).and_return({
        region: 'us-east-1', access_key_id: 'key', secret_access_key: 'secret', bucket_name: 'bucket'
      })
      described_class.new
    end

    it 'delegates to S3 put_object' do
      io = StringIO.new('data')
      allow(s3_client_double).to receive(:put_object)

      service.upload_stream(io, 'path/to/file.jpg')

      expect(s3_client_double).to have_received(:put_object).with(
        bucket: 'bucket', key: 'path/to/file.jpg', body: io
      )
    end
  end

  describe '#file_exists?' do
    let(:service) do
      allow(Rails.application.credentials).to receive(:dig).with(:aws).and_return({
        region: 'us-east-1', access_key_id: 'key', secret_access_key: 'secret', bucket_name: 'bucket'
      })
      described_class.new
    end

    it 'returns true when file exists' do
      allow(s3_client_double).to receive(:head_object)
      expect(service.file_exists?('existing.jpg')).to be true
    end

    it 'returns false when file does not exist' do
      allow(s3_client_double).to receive(:head_object).and_raise(Aws::S3::Errors::NotFound.new(nil, 'not found'))
      expect(service.file_exists?('missing.jpg')).to be false
    end
  end
end
