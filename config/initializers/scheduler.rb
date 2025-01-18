require 'rufus-scheduler'

# Don't schedule jobs in test environment or when running rake tasks
unless defined?(Rails::Console) || Rails.env.test? || File.split($0).last == 'rake'
  scheduler = Rufus::Scheduler.new

  scheduler.every '5m' do
    PreviewService::GenerationMonitor.check_stalled_jobs
  end

  scheduler.every '1h' do
    PreviewService::GenerationMonitor.retry_failed
  end

  scheduler.every '1d' do
    PreviewService::GenerationMonitor.cleanup_old_previews
  end
end
