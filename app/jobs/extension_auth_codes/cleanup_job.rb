# frozen_string_literal: true

module ExtensionAuthCodes
  # Daily sweep that deletes extension auth codes past their expiry. Codes
  # live for a minute, used or not, so nothing expired is worth keeping.
  class CleanupJob < ApplicationJob
    queue_as :maintenance

    def perform
      ExtensionAuthCode.expired.in_batches.delete_all
    end
  end
end
