# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Granblue::Downloaders::BaseDownloader do
  # Concrete test subclass
  let(:test_downloader_class) do
    Class.new(described_class) do
      const_set(:SIZES, %w[main grid].freeze) unless const_defined?(:SIZES)

      private

      def object_type
        'test_object'
      end

      def base_url
        'https://example.com/assets'
      end

      def directory_for_size(size)
        case size
        when 'main' then 'large'
        when 'grid' then 'medium'
        end
      end
    end
  end

  let(:aws_double) { double('AwsService', file_exists?: false, upload_stream: nil) }

  before do
    allow(AwsService).to receive(:new).and_return(aws_double)
    allow(FileUtils).to receive(:mkdir_p)
    allow(Rails).to receive(:root).and_return(Pathname.new('/app'))
    test_downloader_class.reset_aws_service
  end

  describe '#build_url' do
    let(:downloader) { test_downloader_class.new('12345', test_mode: true) }

    it 'constructs URL from base_url, directory, and id' do
      url = downloader.send(:build_url, 'main')
      expect(url).to eq('https://example.com/assets/large/12345.jpg')
    end
  end

  describe '#build_s3_key' do
    let(:downloader) { test_downloader_class.new('12345', test_mode: true) }

    it 'constructs S3 key from object_type, size, and filename' do
      key = downloader.send(:build_s3_key, 'main', '12345.jpg')
      expect(key).to eq('test_object-main/12345.jpg')
    end
  end

  describe '#download_path' do
    let(:downloader) { test_downloader_class.new('12345', test_mode: true) }

    it 'returns path under Rails.root/download' do
      path = downloader.send(:download_path, 'main')
      expect(path).to eq('/app/download/test_object-main')
    end
  end

  describe '#store_locally? and #store_in_s3?' do
    it 'returns correct flags for :local storage' do
      d = test_downloader_class.new('12345', storage: :local, test_mode: true)
      expect(d.send(:store_locally?)).to be true
      expect(d.send(:store_in_s3?)).to be false
    end

    it 'returns correct flags for :s3 storage' do
      d = test_downloader_class.new('12345', storage: :s3, test_mode: true)
      expect(d.send(:store_locally?)).to be false
      expect(d.send(:store_in_s3?)).to be true
    end

    it 'returns correct flags for :both storage' do
      d = test_downloader_class.new('12345', storage: :both, test_mode: true)
      expect(d.send(:store_locally?)).to be true
      expect(d.send(:store_in_s3?)).to be true
    end
  end

  describe '#should_download?' do
    context 'with force flag' do
      let(:downloader) { test_downloader_class.new('12345', force: true, test_mode: true) }

      it 'always returns true' do
        expect(downloader.send(:should_download?, '/path', 'key')).to be true
      end
    end

    context 'with :local storage' do
      let(:downloader) { test_downloader_class.new('12345', storage: :local, test_mode: true) }

      it 'returns true when file does not exist' do
        allow(File).to receive(:exist?).and_return(false)
        expect(downloader.send(:should_download?, '/path', 'key')).to be true
      end

      it 'returns false when file exists' do
        allow(File).to receive(:exist?).and_return(true)
        expect(downloader.send(:should_download?, '/path', 'key')).to be false
      end
    end

    context 'with :s3 storage' do
      let(:downloader) { test_downloader_class.new('12345', storage: :s3, test_mode: true) }

      it 'returns true when S3 file does not exist' do
        allow(aws_double).to receive(:file_exists?).and_return(false)
        expect(downloader.send(:should_download?, '/path', 'key')).to be true
      end

      it 'returns false when S3 file exists' do
        allow(aws_double).to receive(:file_exists?).and_return(true)
        expect(downloader.send(:should_download?, '/path', 'key')).to be false
      end
    end
  end

  describe '#download' do
    it 'returns early in test mode' do
      downloader = test_downloader_class.new('12345', test_mode: true)
      expect(downloader).not_to receive(:process_download)
      downloader.download
    end
  end

  describe 'abstract methods' do
    it 'raises NotImplementedError for object_type' do
      expect { described_class.new('12345', test_mode: true) }.to raise_error(NotImplementedError)
    end
  end
end
