# frozen_string_literal: true

# Development only: re-export data/weapon_skill_curation.json after curated rows change
# (docs/weapon-skill-curation.md). Requests flush after each controller action; other
# processes flush on exit.
Rails.application.config.after_initialize do
  next unless Granblue::CurationAutoExport.enabled?

  ActiveSupport::Notifications.subscribe("process_action.action_controller") do
    Granblue::CurationAutoExport.flush!
  end

  # Rake clears its task list before process exit, so read it now (`bin/rails data:migrate`
  # had left the exit hook with an empty list and bulk edits unexported).
  tasks = defined?(Rake) && Rake.respond_to?(:application) ? Rake.application.top_level_tasks.dup : []
  at_exit do
    if Granblue::CurationAutoExport.rake_bulk_task?(tasks)
      Granblue::CurationAutoExport.export_if_drifted!
    else
      Granblue::CurationAutoExport.flush!
    end
  end
end
