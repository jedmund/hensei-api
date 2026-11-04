# frozen_string_literal: true

module PartyDifficulty
  # Raised by DraftWorkspace#commit! when a staged update or destroy targets a
  # record that another editor has changed since the draft was staged. The
  # controller turns this into a 409 Conflict.
  class StaleDraftError < StandardError
    attr_reader :draft_id, :target_type, :target_id

    def initialize(draft)
      @draft_id = draft.id
      @target_type = draft.target_type
      @target_id = draft.target_id
      super("Draft #{draft.id} is stale: target #{draft.target_type}/#{draft.target_id} changed after stage")
    end
  end

  # Raised by DraftWorkspace#commit! when the merged canonical+drafts tier set
  # would leave [0, 100] partially uncovered or overlapping. The controller
  # turns this into a 422 with the full list of aggregate messages.
  class CoverageError < StandardError
    attr_reader :messages

    def initialize(messages)
      @messages = Array(messages)
      super(@messages.join('; '))
    end
  end

  ##
  # Per-editor staging layer for difficulty rules / tiers / components.
  # Editors mutate state here via the controllers, hit Preview to validate,
  # iterate, and explicitly commit. Other consumers (the public list, the
  # background score sweep) keep reading the canonical tables.
  class DraftWorkspace
    EDITABLE_COLUMNS = {
      'Difficulty' => %w[name slug description min_score max_score sort_order].freeze,
      'DifficultyRule' => %w[name description component rule_type params weight active].freeze,
      'DifficultyComponent' => %w[weight enabled min_count_to_score target_max].freeze
    }.freeze

    SUMMARY_COLUMNS = {
      'Difficulty' => %w[name slug min_score max_score sort_order],
      'DifficultyRule' => %w[name component rule_type weight active],
      'DifficultyComponent' => %w[name weight enabled min_count_to_score target_max]
    }.freeze

    # Stable canonical prefix; the editor writes drafts under the `_drafts/`
    # subkey so a per-draft temp file never collides with a live tier icon.
    IMAGE_FINAL_PREFIX = 'images/difficulties'
    IMAGE_DRAFT_PREFIX = 'images/difficulties/_drafts'

    def self.for(user)
      new(user)
    end

    # The attributes an editor may stage for a target type, with string keys.
    def self.sanitize_attributes(target_type, attrs)
      allowed = EDITABLE_COLUMNS[target_type] || []
      attrs = attrs.to_unsafe_h if attrs.respond_to?(:to_unsafe_h)
      (attrs || {}).each_with_object({}) do |(key, value), out|
        out[key.to_s] = value if allowed.include?(key.to_s)
      end
    end

    def initialize(user)
      @user = user
      @drafts = DifficultyDraft.for_user(user).to_a
    end

    attr_reader :user, :drafts

    def pending_count
      @drafts.size
    end

    def merged_tiers
      merge_collection(Difficulty.ordered.to_a, 'Difficulty', sort_by: :sort_order)
    end

    # When `only_active` is true, return only rules whose `active` flag is set
    # (matching `DifficultyRule.active.to_a` in Calculator). The preview path
    # needs this so a staged-but-inactive rule doesn't score differently than
    # the canonical engine would after commit.
    def merged_rules(only_active: false)
      merged = merge_collection(DifficultyRule.order(:component, :name).to_a, 'DifficultyRule', sort_by: :name)
      only_active ? merged.select(&:active) : merged
    end

    def merged_components
      merge_collection(DifficultyComponent.order(:name).to_a, 'DifficultyComponent', sort_by: :name)
    end

    def diff
      {
        tiers: section_diff('Difficulty'),
        rules: section_diff('DifficultyRule'),
        components: section_diff('DifficultyComponent')
      }
    end

    def commit!(note: nil)
      ApplicationRecord.transaction do
        snapshot = diff
        # Multi-tier boundary edits can't tile [0, 100] mid-save, so validate
        # the aggregate post-commit set up front and suppress the per-row
        # coverage check while we apply.
        coverage_messages = Difficulty.coverage_errors_for(merged_tiers)
        raise CoverageError, coverage_messages if coverage_messages.any?

        # Each apply! triggers the per-record after_save :bump_ruleset_version
        # callback on Difficulty / DifficultyRule / DifficultyComponent, so the
        # version increases by N. The log records the final post-apply version;
        # we don't add an extra explicit bump here.
        Difficulty.with_coverage_validation_skipped do
          @drafts.each { |draft| apply!(draft) }
        end
        log = DifficultyChangeLog.create!(
          user: @user,
          note: note.presence,
          changes_payload: snapshot,
          ruleset_version_after: DifficultyConfig.current_version,
          committed_at: Time.current
        )
        @drafts.each(&:destroy)
        @drafts = []
        log
      end
    end

    def discard!
      Images.delete_staged(@drafts)
      destroyed = DifficultyDraft.for_user(@user).destroy_all
      @drafts = []
      destroyed.size
    end

    ##
    # Drops a single draft, cleaning up any temp S3 object that was staged
    # against it. Returns true if the draft was destroyed.
    def delete_draft!(draft)
      Images.delete_staged([draft])
      destroyed = draft.destroy
      @drafts.reject! { |d| d.id == draft.id }
      @grouped_drafts = nil
      destroyed
    end

    ##
    # Stages an icon image for a Difficulty draft. Uploads the bytes to a
    # draft-scoped S3 key and records that key on the draft's attributes so
    # commit! can promote it to the canonical key once the tier's id is known.
    def attach_image!(draft, image_data:, filename: nil)
      raise ArgumentError, 'attach_image! only supports Difficulty drafts' unless draft.target_type == 'Difficulty'

      Images.stage!(draft, image_data: image_data, filename: filename)
    end

    # Raised by attach_image! when the uploaded bytes fail validation. The
    # controller maps this to a 422 with the validator's message.
    class ImageValidationError < StandardError; end

    ##
    # Upserts a draft for the given target. Returns the saved DifficultyDraft.
    # For update / destroy operations, an existing draft for the same target is
    # replaced. Create operations always insert a new row.
    def stage!(target_type:, target_id:, operation:, attributes:)
      target_type = target_type.to_s
      operation = operation.to_s
      raise ArgumentError, "Unknown target_type #{target_type}" unless EDITABLE_COLUMNS.key?(target_type)
      raise ArgumentError, "Unknown operation #{operation}" unless DifficultyDraft::OPERATIONS.include?(operation)

      payload = sanitize_attributes(target_type, attributes || {})

      @grouped_drafts = nil
      if operation == 'create'
        stage_create!(target_type, payload)
      else
        stage_change!(target_type, target_id, operation, payload)
      end
    end

    # Pending creations use their draft UUID as the virtual rule ID.
    def created_rule_draft(id)
      DifficultyDraft.for_user(@user).find_by(id: id, target_type: 'DifficultyRule', operation: 'create')
    end

    def update_created_rule!(draft, attributes)
      draft = created_rule_draft(draft.id)
      raise ActiveRecord::RecordNotFound unless draft

      payload = draft.attributes_payload.merge(sanitize_attributes('DifficultyRule', attributes))
      DifficultyRule.new(payload).validate!
      draft.update!(attributes_payload: payload)
      @drafts.map! { |entry| entry.id == draft.id ? draft : entry }
      @grouped_drafts = nil
      draft
    end

    private

    # A created rule must be valid on its own.
    def stage_create!(target_type, payload)
      DifficultyRule.new(payload).validate! if target_type == 'DifficultyRule'

      DifficultyDraft.create!(
        user: @user,
        target_type: target_type,
        target_id: nil,
        operation: 'create',
        attributes_payload: payload
      ).tap { |d| @drafts << d }
    end

    # Replaces the target's update or destroy draft. A rule update merges into the
    # staged edits and must leave the rule valid.
    def stage_change!(target_type, target_id, operation, payload)
      # Snapshot the current target's updated_at so commit! can detect a
      # concurrent edit by another editor.
      target = target_type.constantize.find_by(id: target_id)
      draft = DifficultyDraft.find_or_initialize_by(
        user: @user,
        target_type: target_type,
        target_id: target_id
      )
      if target_type == 'DifficultyRule' && operation == 'update'
        payload = draft.attributes_payload.merge(payload)
        raise ActiveRecord::RecordNotFound unless target

        candidate = target.dup
        candidate.assign_attributes(payload)
        candidate.validate!
      end
      draft.operation = operation
      draft.attributes_payload = operation == 'destroy' ? {} : payload
      draft.target_updated_at = target&.updated_at
      draft.save!
      @drafts.reject! { |d| d.id == draft.id }
      @drafts << draft
      draft
    end

    def merge_collection(canonical, target_type, sort_by:)
      by_target = grouped_drafts[target_type] || []
      drafts_by_target = by_target.reject { |d| d.operation == 'create' }.index_by(&:target_id)

      kept = canonical.flat_map do |record|
        draft = drafts_by_target[record.id]
        next [decorate(record, nil)] unless draft

        case draft.operation
        when 'destroy' then []
        when 'update' then [build_updated(record, draft)]
        else [decorate(record, nil)]
        end
      end

      creates = by_target.select { |d| d.operation == 'create' }.map { |d| build_created(target_type, d) }
      sort_records(kept + creates, sort_by)
    end

    def grouped_drafts
      @grouped_drafts ||= @drafts.group_by(&:target_type)
    end

    def build_updated(record, draft)
      cloned = record.class.find(record.id) # fresh copy to avoid mutating cache
      apply_attrs(cloned, draft.attributes_payload)
      decorate(cloned, draft)
    end

    def build_created(target_type, draft)
      klass = target_type.constantize
      record = klass.new(sanitize_attributes(target_type, draft.attributes_payload))
      record.id = draft.id # virtual id so the UI can subsequently address this draft
      record.created_at ||= draft.created_at
      record.updated_at ||= draft.updated_at
      decorate(record, draft)
    end

    def decorate(record, draft)
      pending = !draft.nil?
      operation = draft&.operation
      draft_id = draft&.id
      record.define_singleton_method(:pending?) { pending }
      record.define_singleton_method(:pending_operation) { operation }
      record.define_singleton_method(:draft_id) { draft_id }
      record
    end

    def sort_records(records, sort_by)
      records.sort_by { |r| [sort_value(r, sort_by), r.try(:name).to_s] }
    end

    def sort_value(record, sort_by)
      value = record.respond_to?(sort_by) ? record.public_send(sort_by) : nil
      value.is_a?(Numeric) ? value : value.to_s
    end

    def sanitize_attributes(target_type, attrs)
      self.class.sanitize_attributes(target_type, attrs)
    end

    def apply_attrs(record, attrs)
      sanitize_attributes(record.class.name, attrs).each { |k, v| record[k] = v }
    end

    def section_diff(target_type)
      Diff.new(target_type, grouped_drafts[target_type] || []).to_h
    end

    def apply!(draft)
      case draft.operation
      when 'create'
        klass = draft.target_class
        record = klass.create!(sanitize_attributes(draft.target_type, draft.attributes_payload))
        Images.promote(draft, record)
      when 'update'
        target = lock_and_verify(draft)
        target&.update!(sanitize_attributes(draft.target_type, draft.attributes_payload))
        Images.promote(draft, target) if target
      when 'destroy'
        target = lock_and_verify(draft)
        Images.delete_canonical(target) if target.is_a?(Difficulty)
        target&.destroy!
      end
    end

    # Locks the target row for the rest of the commit transaction and raises
    # StaleDraftError if the target's updated_at no longer matches the
    # snapshot captured at stage time. Drafts without a snapshot (created
    # before the optimistic-concurrency column existed) skip the check.
    def lock_and_verify(draft)
      target = draft.target&.lock!
      return target if target.nil?
      return target if draft.target_updated_at.nil?
      return target if target.updated_at == draft.target_updated_at

      raise StaleDraftError, draft
    end
  end
end
