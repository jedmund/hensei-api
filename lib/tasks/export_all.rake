namespace :granblue do
  namespace :export do
    desc 'Exports files of URLs for every object at every size'
    task :all do
      # Run character tasks
      Rake::Task['granblue:export:character'].invoke('main')
      Rake::Task['granblue:export:character'].reenable

      Rake::Task['granblue:export:character'].invoke('grid')
      Rake::Task['granblue:export:character'].reenable

      Rake::Task['granblue:export:character'].invoke('square')
      Rake::Task['granblue:export:character'].reenable

      # Run weapon tasks
      Rake::Task['granblue:export:weapon'].invoke('main')
      Rake::Task['granblue:export:weapon'].reenable

      Rake::Task['granblue:export:weapon'].invoke('grid')
      Rake::Task['granblue:export:weapon'].reenable

      Rake::Task['granblue:export:weapon'].invoke('square')
      Rake::Task['granblue:export:weapon'].reenable

      # Run summon tasks
      Rake::Task['granblue:export:summon'].invoke('main')
      Rake::Task['granblue:export:summon'].reenable

      Rake::Task['granblue:export:summon'].invoke('grid')
      Rake::Task['granblue:export:summon'].reenable

      Rake::Task['granblue:export:summon'].invoke('square')
      Rake::Task['granblue:export:summon'].reenable

      # Run job tasks
      Rake::Task['granblue:export:job'].invoke
      Rake::Task['granblue:export:job'].reenable

      puts 'Exported 10 files'
    end
  end
end
