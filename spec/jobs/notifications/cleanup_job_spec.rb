# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::CleanupJob, type: :job do
  let(:user) { create(:user) }
  let(:party) { create(:party, user: user) }
  let(:crew) { create(:crew) }
  let(:member) { create(:user).tap { |m| create(:crew_membership, crew: crew, user: m, role: :member) } }

  # Publisher callbacks may already have written the row; reuse it
  def notification(subject, kind:, recipient: user, updated: 1.day.ago, read: nil)
    row = Notification.find_or_create_by!(recipient: recipient, kind: kind, subject: subject)
    row.update_columns(updated_at: updated, read_at: read)
    row
  end

  def invitation(*traits)
    create(:crew_invitation, *traits, crew: crew, user: user)
  end

  def phantom(*traits, **attrs)
    create(:phantom_player, *traits, crew: crew, claimer: member, **attrs)
  end

  def run_and_survivors(*rows)
    described_class.perform_now
    rows.select { |row| Notification.exists?(row.id) }
  end

  describe 'read notifications' do
    it 'deletes rows read more than 90 days ago and keeps ones read since' do
      freeze_time do
        old = notification(party, kind: :party_featured, read: 90.days.ago - 1.minute, updated: 1.year.ago)
        recent = notification(create(:party, user: user), kind: :party_featured,
                                                          read: 90.days.ago + 1.minute, updated: 1.year.ago)

        expect(run_and_survivors(old, recent)).to eq([recent])
      end
    end

    it 'keeps pending invitations and phantom assignments read long ago' do
      pending_invitation = notification(invitation, kind: :crew_invited, read: 1.year.ago, updated: 1.year.ago)
      pending_phantom = notification(phantom(:claimed), kind: :phantom_assigned, recipient: member,
                                                        read: 1.year.ago, updated: 1.year.ago)

      expect(run_and_survivors(pending_invitation, pending_phantom)).to eq([pending_invitation, pending_phantom])
    end

    it 'deletes a resolved invitation read over 90 days ago even if updated since' do
      row = notification(invitation(:accepted), kind: :crew_invited, read: 91.days.ago, updated: 1.day.ago)
      expect(run_and_survivors(row)).to be_empty
    end
  end

  it 'keeps unread passive notifications of any age' do
    row = notification(party, kind: :sticker_received, updated: 5.years.ago)
    expect(run_and_survivors(row)).to eq([row])
  end

  describe 'actionable notifications' do
    it 'keeps an old pending invitation' do
      row = notification(invitation, kind: :crew_invited, updated: 1.year.ago)
      expect(run_and_survivors(row)).to eq([row])
    end

    it 'keeps an old pending phantom assignment' do
      row = notification(phantom(:claimed), kind: :phantom_assigned, recipient: member, updated: 1.year.ago)
      expect(run_and_survivors(row)).to eq([row])
    end

    it 'deletes resolved invitations older than 90 days, read or not' do
      accepted = notification(invitation(:accepted), kind: :crew_invited, updated: 91.days.ago)
      rejected = notification(invitation(:rejected), kind: :crew_invited, updated: 91.days.ago, read: 10.days.ago)
      lapsed = notification(invitation(:expired_by_time), kind: :crew_invited, updated: 91.days.ago)

      expect(run_and_survivors(accepted, rejected, lapsed)).to be_empty
    end

    it 'deletes resolved phantom assignments older than 90 days' do
      confirmed = notification(phantom(:confirmed), kind: :phantom_assigned, recipient: member, updated: 91.days.ago)
      deleted = notification(phantom(:claimed, deleted_at: 1.day.ago), kind: :phantom_assigned, recipient: member, updated: 91.days.ago)
      reassigned = notification(create(:phantom_player, :claimed, crew: crew), kind: :phantom_assigned, recipient: member,
                                                                               updated: 91.days.ago)

      expect(run_and_survivors(confirmed, deleted, reassigned)).to be_empty
    end

    it 'deletes rows whose subject no longer exists' do
      gone = invitation
      row = notification(gone, kind: :crew_invited, updated: 91.days.ago)
      gone.delete

      expect(run_and_survivors(row)).to be_empty
    end

    it 'keeps resolved rows until they are 90 days old' do
      freeze_time do
        inside = notification(invitation(:accepted), kind: :crew_invited, updated: 90.days.ago + 1.minute)
        outside = notification(phantom(:confirmed), kind: :phantom_assigned, recipient: member, updated: 90.days.ago - 1.minute)

        expect(run_and_survivors(inside, outside)).to eq([inside])
      end
    end
  end

  it 'logs what it deleted' do
    notification(party, kind: :party_featured, read: 91.days.ago)
    allow(Rails.logger).to receive(:info)

    described_class.perform_now

    expect(Rails.logger).to have_received(:info).with(/deleted 1 read and 0 resolved/)
  end

  it 'is scheduled daily on the maintenance queue' do
    schedule = YAML.load_file(Rails.root.join('config/sidekiq.yml')).dig(:scheduler, :schedule)
    expect(schedule['notification_cleanup']).to include('class' => described_class.name, 'queue' => 'maintenance',
                                                        'cron' => '20 4 * * *')
  end
end
