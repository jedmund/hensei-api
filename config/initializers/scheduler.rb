require 'rufus-scheduler'

# Don't schedule jobs in test environment or when running rake tasks
unless defined?(Rails::Console) || Rails.env.test? || File.split($0).last == 'rake'
  Rufus::Scheduler.new
end
