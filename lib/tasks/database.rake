namespace :db do
  desc 'Backup remote PostgreSQL database'
  task :backup do
    remote_host = ENV.fetch('REMOTE_DB_HOST', 'roundhouse.proxy.rlwy.net')
    remote_port = ENV.fetch('REMOTE_DB_PORT', '54629')
    remote_user = ENV.fetch('REMOTE_DB_USER', 'postgres')
    remote_db = ENV.fetch('REMOTE_DB_NAME', 'railway')
    password = ENV.fetch('REMOTE_DB_PASSWORD') { raise 'Please set REMOTE_DB_PASSWORD' }

    backup_dir = File.expand_path('backups')
    FileUtils.mkdir_p(backup_dir)
    backup_file = File.join(backup_dir, "#{Time.now.strftime('%Y%m%d_%H%M%S')}-prod-backup.tar")

    cmd = %W[
      pg_dump -h #{remote_host} -p #{remote_port} -U #{remote_user} -d #{remote_db} -F t
      --no-owner --exclude-extension=timescaledb --exclude-extension=timescaledb_toolkit
    ].join(' ')

    puts "Backing up remote database to #{backup_file}..."
    system({ 'PGPASSWORD' => password }, "#{cmd} > #{backup_file}")
    puts 'Backup completed!'
  end

  desc 'Restore PostgreSQL database from backup'
  task :restore, [:backup_file] => [:environment] do |_, args|
    local_user = ENV.fetch('LOCAL_DB_USER', 'justin')
    local_db = ENV.fetch('LOCAL_DB_NAME', 'hensei_dev')

    # Use the specified backup file or find the most recent one
    backup_dir = File.expand_path('backups')
    backup_file = args[:backup_file] || Dir.glob("#{backup_dir}/*-prod-backup.tar").max

    raise 'Backup file not found. Please specify a valid backup file.' unless backup_file && File.exist?(backup_file)

    puts "Restoring database from #{backup_file}..."
    system("pg_restore --no-owner --role=#{local_user} --disable-triggers -U #{local_user} -d #{local_db} #{backup_file}")
    puts 'Restore completed!'
  end

  desc 'Backup remote database and restore locally'
  task backup_and_restore: %i[backup restore]
end
