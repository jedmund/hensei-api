# frozen_string_literal: true

module WikiImport
  ##
  # Creates the party and its grid from a resolved wiki team. A grid item the
  # models reject is skipped with a warning; the rest of the party still
  # imports. Callers own the transaction.
  class PartyBuilder
    # @param plan [Hash] the resolved team: :job (a JobResolver::Result),
    #   :characters, :summons, :weapons (item plans) and :bullets
    # @param payload [WikiImport::Payload]
    # @param user [User, nil]
    # @param report [WikiImport::Report]
    def initialize(plan, payload:, user:, report:)
      @plan = plan
      @payload = payload
      @user = user
      @report = report
    end

    # @return [Party]
    def build
      party = create_party
      @plan[:characters].each { |item| create_character(party, item) }
      @plan[:summons].each { |item| create_summon(party, item) }
      @plan[:weapons].each { |item| create_weapon(party, item) }
      # Party's after_commit callbacks read these; drop anything cached mid-import.
      party.characters.reset
      party.weapons.reset
      party.summons.reset
      party
    end

    private

    def create_party
      job = @plan[:job]
      Party.create!(
        user: @user,
        # Lets an anonymous creator keep edit rights after a reload.
        local_id: @user ? nil : @payload.local_id,
        last_updated: Time.current,
        job: job.job,
        skill0: job.skill0,
        skill1: job.skills[0],
        skill2: job.skills[1],
        skill3: job.skills[2],
        accessory: job.accessory,
        full_auto_skills: job.full_auto_skills
      )
    end

    def create_character(party, item)
      party.characters.reset
      if party.characters.any? { |gc| gc.character_id == item[:record].id }
        return @report.warn('invalid_item', "character #{item[:entry].position}: already in the party",
                            **Report.at(:character, item[:entry]))
      end

      grid_character = GridCharacter.new(
        party: party,
        character: item[:record],
        position: item[:entry].position,
        uncap_level: item[:uncap],
        transcendence_step: item[:step],
        awakening: item[:awakening],
        perpetuity: item[:ring],
        full_auto_skills: item[:full_auto_skills]
      )
      saved_item?(:character, item, grid_character)
      nil
    end

    def create_summon(party, item)
      position = item[:entry].position
      party.summons.reset
      grid_summon = GridSummon.new(
        party: party,
        summon: item[:record],
        position: position,
        main: position == -1,
        friend: position == GridSummon::FRIEND_POSITION,
        quick_summon: position == @payload.quick,
        uncap_level: item[:uncap],
        transcendence_step: item[:step]
      )
      saved_item?(:summon, item, grid_summon)
      nil
    end

    def create_weapon(party, item)
      party.weapons.reset
      grid_weapon = GridWeapon.new(
        party: party,
        weapon: item[:record],
        position: item[:entry].position,
        uncap_level: item[:uncap],
        transcendence_step: item[:step],
        element: item[:element],
        awakening: item[:awakening]
      )
      item[:keys].each { |slot, key| grid_weapon.public_send(:"weapon_key#{slot + 1}_id=", key.id) }
      return unless saved_item?(:weapon, item, grid_weapon)

      create_bullets(grid_weapon) if grid_weapon.position == -1
    end

    def create_bullets(grid_weapon)
      @plan[:bullets].each do |bullet, slot, index|
        record = GridWeaponBullet.new(grid_weapon: grid_weapon, bullet: bullet, position: slot)
        next if record.save

        @report.warn('invalid_item', "bullet #{bullet.slug}: #{record.errors.full_messages.to_sentence}",
                     kind: 'bullet', position: index, title: bullet.slug)
      end
    end

    def saved_item?(kind, item, record)
      return true if record.save

      @report.warn('invalid_item', "#{kind} #{item[:entry].position}: #{record.errors.full_messages.to_sentence}",
                   **Report.at(kind, item[:entry]))
      false
    end
  end
end
