# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'db:restore' do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'db:restore' }
  end

  def config_for(url)
    ActiveRecord::DatabaseConfigurations::UrlConfig.new('development', 'primary', url, {})
  end

  describe LocalDatabase do
    it 'treats sockets and loopback hosts as local' do
      expect([nil, '', '/tmp', 'localhost', '127.0.0.1', '::1'].map { |h| described_class.local_host?(h) }).to all(be(true))
    end

    it 'treats any other host as remote' do
      expect(described_class.local_host?('db.example.com')).to be(false)
      expect(described_class.local_host?('10.0.0.5')).to be(false)
    end
  end

  it 'refuses a remote database before dropping or restoring anything' do
    remote = config_for('postgres://user:secret@db.example.com:5432/railway')
    allow(ActiveRecord::Base).to receive(:connection_db_config).and_return(remote)
    expect(Rake::Task['db:drop']).not_to receive(:invoke)

    ENV['CLEAN'] = '1'
    Rake::Task['db:restore'].reenable
    expect { Rake::Task['db:restore'].invoke }.to raise_error(/Refusing to restore into railway on db.example.com/)
  ensure
    ENV.delete('CLEAN')
  end
end
