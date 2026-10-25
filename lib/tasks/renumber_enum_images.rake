# frozen_string_literal: true

namespace :granblue do
  desc <<~DESC
    Rename bucket images whose names carry an element or proficiency number to the game's
    numbers (after data migration 20261024120000). See Granblue::EnumImageRenumbering.
    Run the steps in order, checking the site before cleanup:
      rake granblue:renumber_enum_images step=plan
      rake granblue:renumber_enum_images step=stage
      rake granblue:renumber_enum_images step=apply
      rake granblue:renumber_enum_images step=cleanup
  DESC
  task renumber_enum_images: :environment do
    step = ENV.fetch('step', 'plan')
    abort "Unknown step #{step.inspect}" unless %w[plan stage apply cleanup].include?(step)

    Granblue::EnumImageRenumbering.new.public_send(step)
  end
end
