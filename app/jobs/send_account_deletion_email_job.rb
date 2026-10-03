# frozen_string_literal: true

class SendAccountDeletionEmailJob < ApplicationJob
  queue_as :default

  def perform(user_id, kind)
    user = User.find_by(id: user_id)
    return unless user

    case kind
    when 'scheduled' then AccountDeletionMailer.scheduled_email(user).deliver_now
    when 'cancelled' then AccountDeletionMailer.cancelled_email(user).deliver_now
    end
  end
end
