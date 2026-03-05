# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreviewService::ImageFetcherService do
  let(:s3_client_double) { double('Aws::S3::Client') }
  let(:aws_service) { double('AwsService', s3_client: s3_client_double, bucket: 'test-bucket') }
  let(:fetcher) { described_class.new(aws_service) }

  let(:s3_response) { double('S3Response', body: StringIO.new('image-data')) }

  before do
    allow(Rails.logger).to receive(:error)
  end

  describe '#fetch_s3_image' do
    it 'downloads image from S3 and returns MiniMagick image' do
      allow(s3_client_double).to receive(:get_object).and_return(s3_response)
      allow(MiniMagick::Image).to receive(:new).and_return(double('MiniMagickImage'))

      result = fetcher.fetch_s3_image('test.jpg')
      expect(result).not_to be_nil
      expect(s3_client_double).to have_received(:get_object).with(
        bucket: 'test-bucket', key: 'test.jpg'
      )
    end

    it 'prepends folder to key when provided' do
      allow(s3_client_double).to receive(:get_object).and_return(s3_response)
      allow(MiniMagick::Image).to receive(:new).and_return(double('MiniMagickImage'))

      fetcher.fetch_s3_image('test.jpg', 'icons')
      expect(s3_client_double).to have_received(:get_object).with(
        bucket: 'test-bucket', key: 'icons/test.jpg'
      )
    end

    it 'returns nil on error' do
      allow(s3_client_double).to receive(:get_object).and_raise(StandardError, 'S3 error')

      result = fetcher.fetch_s3_image('missing.jpg')
      expect(result).to be_nil
    end
  end

  describe '#fetch_job_icon' do
    it 'fetches from job-icons folder' do
      allow(s3_client_double).to receive(:get_object).and_return(s3_response)
      allow(MiniMagick::Image).to receive(:new).and_return(double('MiniMagickImage'))

      fetcher.fetch_job_icon('Warrior')
      expect(s3_client_double).to have_received(:get_object).with(
        bucket: 'test-bucket', key: 'job-icons/warrior.png'
      )
    end
  end

  describe '#fetch_weapon_image' do
    let(:weapon) { double('Weapon', granblue_id: '1040001000') }

    it 'fetches from weapon-grid folder by default' do
      allow(s3_client_double).to receive(:get_object).and_return(s3_response)
      allow(MiniMagick::Image).to receive(:new).and_return(double('MiniMagickImage'))

      fetcher.fetch_weapon_image(weapon)
      expect(s3_client_double).to have_received(:get_object).with(
        bucket: 'test-bucket', key: 'weapon-grid/1040001000.jpg'
      )
    end

    it 'fetches from weapon-main folder when mainhand' do
      allow(s3_client_double).to receive(:get_object).and_return(s3_response)
      allow(MiniMagick::Image).to receive(:new).and_return(double('MiniMagickImage'))

      fetcher.fetch_weapon_image(weapon, mainhand: true)
      expect(s3_client_double).to have_received(:get_object).with(
        bucket: 'test-bucket', key: 'weapon-main/1040001000.jpg'
      )
    end
  end

  describe '#fetch_user_picture' do
    it 'fetches from profile folder' do
      allow(s3_client_double).to receive(:get_object).and_return(s3_response)
      allow(MiniMagick::Image).to receive(:new).and_return(double('MiniMagickImage'))

      fetcher.fetch_user_picture('avatar123')
      expect(s3_client_double).to have_received(:get_object).with(
        bucket: 'test-bucket', key: 'profile/avatar123.png'
      )
    end
  end

  describe '#cleanup' do
    it 'closes and unlinks all tracked tempfiles' do
      tempfile = double('Tempfile')
      allow(tempfile).to receive(:close)
      allow(tempfile).to receive(:unlink)

      # Simulate tempfile tracking by using internal state
      fetcher.instance_variable_set(:@tempfiles, [tempfile])
      fetcher.cleanup

      aggregate_failures do
        expect(tempfile).to have_received(:close)
        expect(tempfile).to have_received(:unlink)
      end
    end
  end
end
