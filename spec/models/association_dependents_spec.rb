# frozen_string_literal: true

require 'rails_helper'

# What destroying a parent does to the rows of each association whose
# `dependent:` option was chosen by hand (see the model comments).
RSpec.describe 'Association dependents' do # rubocop:disable RSpec/DescribeClass
  describe Awakening do
    it 'cannot be destroyed while a weapon lists it' do
      awakening = create(:awakening, :for_weapon)
      create(:weapon_awakening, awakening: awakening)

      expect { awakening.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
    end
  end

  describe Weapon do
    it 'cannot be destroyed while it lists an awakening' do
      join = create(:weapon_awakening)

      expect { join.weapon.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'leaves its skills behind when destroyed' do
      skill = create(:weapon_skill)

      expect(skill.weapon.destroy).to be_truthy
      expect(WeaponSkill.exists?(skill.id)).to be(true)
    end

    it 'leaves the rest of its forge chain alone when destroyed' do
      root = create(:weapon)
      root.update_columns(forge_chain_id: root.id, forge_order: 0)
      leaf = create(:weapon, forge_chain_id: root.id, forge_order: 1)

      expect(leaf.destroy).to be_truthy
      expect(described_class.exists?(root.id)).to be(true)
    end
  end

  describe Job do
    it 'leaves its skills behind when destroyed' do
      skill = create(:job_skill)

      expect(skill.job.destroy).to be_truthy
      expect(JobSkill.exists?(skill.id)).to be(true)
    end
  end

  describe Character do
    let!(:base) { create(:character) }
    let!(:variant) { create(:character, granblue_id: base.granblue_id, style_swap: true) }

    it 'leaves its style-swap variants alone when destroyed' do
      expect(base.destroy).to be_truthy
      expect(described_class.exists?(variant.id)).to be(true)
    end

    it 'destroys a variant on its own' do
      expect(variant.destroy).to be_truthy
      expect(described_class.exists?(base.id)).to be(true)
    end
  end

  describe Crew do
    it 'takes its active memberships and pending invitations with it' do
      crew = create(:crew)
      membership = create(:crew_membership, :captain, crew: crew)
      invitation = create(:crew_invitation, crew: crew)

      expect(crew.destroy).to be_truthy
      expect(CrewMembership.exists?(membership.id)).to be(false)
      expect(CrewInvitation.exists?(invitation.id)).to be(false)
    end
  end

  describe User do
    it 'takes its active membership with it' do
      membership = create(:crew_membership)

      expect(membership.user.destroy).to be_truthy
      expect(CrewMembership.exists?(membership.id)).to be(false)
    end

    it 'takes its pending invitations with it' do
      invitation = create(:crew_invitation)

      expect(invitation.user.destroy).to be_truthy
      expect(CrewInvitation.exists?(invitation.id)).to be(false)
    end

    it 'cannot be destroyed while it holds a phantom claim' do
      phantom = create(:phantom_player, :claimed)

      expect { phantom.claimed_by.destroy }.to raise_error(ActiveRecord::InvalidForeignKey)
    end

    it 'is destroyed once account deletion has released its phantom claims' do
      phantom = create(:phantom_player, :confirmed)
      user = phantom.claimed_by
      user.update_columns(deletion_scheduled_at: 1.minute.ago)

      expect(AccountDeletion::Purge.call(user)).to be(true)
      expect(phantom.reload).to have_attributes(claimed_by_id: nil, claim_confirmed: false)
    end
  end
end
