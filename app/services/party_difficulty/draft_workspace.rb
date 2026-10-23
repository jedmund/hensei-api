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
      remove_temp_images(@drafts)
      destroyed = DifficultyDraft.for_user(@user).destroy_all
      @drafts = []
      destroyed.size
    end

    ##
    # Drops a single draft, cleaning up any temp S3 object that was staged
    # against it. Returns true if the draft was destroyed.
    def delete_draft!(draft)
      remove_temp_images([draft])
      destroyed = draft.destroy
      @drafts.reject! { |d| d.id == draft.id }
      destroyed
    end

    ##
    # Stages an icon image for a Difficulty draft. Uploads the bytes to a
    # draft-scoped S3 key and records that key on the draft's attributes so
    # commit! can promote it to the canonical key once the tier's id is known.
    def attach_image!(draft, image_data:, filename: nil)
      raise ArgumentError, 'attach_image! only supports Difficulty drafts' unless draft.target_type == 'Difficulty'

      decoded = decode_image(image_data)
      result = IconUploadValidator.call(decoded)
      raise ImageValidationError, result.error unless result.valid?

      key = "#{IMAGE_DRAFT_PREFIX}/#{draft.id}.png"
      IconStorage.put(key, decoded)

      payload = (draft.attributes_payload || {}).merge('image_key' => key)
      payload['image_filename'] = filename if filename.present?
      draft.update!(attributes_payload: payload)
      draft
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

      if operation == 'create'
        DifficultyDraft.create!(
          user: @user,
          target_type: target_type,
          target_id: nil,
          operation: operation,
          attributes_payload: payload
        ).tap { |d| @drafts << d }
      else
        # Snapshot the current target's updated_at so commit! can detect a
        # concurrent edit by another editor.
        target = target_type.constantize.find_by(id: target_id)
        draft = DifficultyDraft.find_or_initialize_by(
          user: @user,
          target_type: target_type,
          target_id: target_id
        )
        draft.operation = operation
        draft.attributes_payload = operation == 'destroy' ? {} : payload
        draft.target_updated_at = target&.updated_at
        draft.save!
        @drafts.reject! { |d| d.id == draft.id }
        @drafts << draft
        draft
      end
    end

    private

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
      allowed = EDITABLE_COLUMNS[target_type] || []
      attrs = attrs.to_unsafe_h if attrs.respond_to?(:to_unsafe_h)
      (attrs || {}).each_with_object({}) do |(key, value), out|
        out[key.to_s] = value if allowed.include?(key.to_s)
      end
    end

    def apply_attrs(record, attrs)
      sanitize_attributes(record.class.name, attrs).each { |k, v| record[k] = v }
    end

    def section_diff(target_type)
      drafts = grouped_drafts[target_type] || []
      creates = []
      updates = []
      destroys = []

      target_ids = drafts.filter_map { |d| d.target_id unless d.operation == 'create' }.uniq
      targets_by_id = target_ids.any? ? target_type.constantize.where(id: target_ids).index_by(&:id) : {}

      drafts.each do |draft|
        case draft.operation
        when 'create'
          creates << {
            draft_id: draft.id,
            attributes: sanitize_attributes(target_type, draft.attributes_payload)
          }
        when 'update'
          target = targets_by_id[draft.target_id]
          if target.nil?
            updates << stale_entry(draft)
            next
          end

          field_diff = compute_field_diff(target, draft.attributes_payload, target_type)
          next if field_diff.empty?

          updates << {
            draft_id: draft.id,
            target_id: target.id,
            label: summary_label(target),
            changes: field_diff,
            stale: stale_against?(target, draft)
          }
        when 'destroy'
          target = targets_by_id[draft.target_id]
          if target.nil?
            destroys << stale_entry(draft)
            next
          end

          destroys << {
            draft_id: draft.id,
            target_id: target.id,
            label: summary_label(target),
            snapshot: target.attributes.slice(*SUMMARY_COLUMNS.fetch(target_type, [])),
            stale: stale_against?(target, draft)
          }
        end
      end

      { creates: creates, updates: updates, destroys: destroys }
    end

    # Emitted for update/destroy drafts whose target has been deleted by
    # another editor since the draft was staged. The frontend can prompt the
    # editor to discard the stranded draft.
    def stale_entry(draft)
      {
        draft_id: draft.id,
        target_id: draft.target_id,
        stale: true,
        reason: 'target_missing'
      }
    end

    def stale_against?(target, draft)
      return false if draft.target_updated_at.nil?

      target.updated_at != draft.target_updated_at
    end

    def compute_field_diff(record, proposed, target_type)
      allowed = EDITABLE_COLUMNS[target_type] || []
      proposed.each_with_object({}) do |(key, new_value), out|
        key = key.to_s
        next unless allowed.include?(key)

        old_value = record[key]
        out[key] = { old: old_value, new: new_value } if normalized(old_value) != normalized(new_value)
      end
    end

    def normalized(value)
      case value
      when BigDecimal then value.to_f
      when Hash then value.deep_stringify_keys
      else value
      end
    end

    def summary_label(record)
      return record.name if record.respond_to?(:name) && record.name.present?

      record.id
    end

    def apply!(draft)
      case draft.operation
      when 'create'
        klass = draft.target_class
        record = klass.create!(sanitize_attributes(draft.target_type, draft.attributes_payload))
        promote_image_if_present(draft, record)
      when 'update'
        target = lock_and_verify(draft)
        target&.update!(sanitize_attributes(draft.target_type, draft.attributes_payload))
        promote_image_if_present(draft, target) if target
      when 'destroy'
        target = lock_and_verify(draft)
        cleanup_canonical_image(target) if target.is_a?(Difficulty)
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

    # When a draft has a `_drafts/`-prefixed image_key in its attributes, copy
    # the staged S3 object to the canonical key and write that key to the row.
    #
    # Ordering matters for retry safety: copy → update_column → best-effort
    # delete. If the DB write fails, the canonical key exists but the row
    # doesn't reference it (orphan, recoverable). If the delete fails, the
    # staged copy lingers — that's intentionally non-fatal, the S3 lifecycle
    # rule on the `_drafts/` prefix sweeps it.
    def promote_image_if_present(draft, record)
      return unless draft.target_type == 'Difficulty'

      staged_key = draft.attributes_payload&.dig('image_key')
      return unless staged_key.is_a?(String) && staged_key.start_with?("#{IMAGE_DRAFT_PREFIX}/")

      final_key = "#{IMAGE_FINAL_PREFIX}/#{record.id}.png"
      IconStorage.copy(staged_key, final_key)
      record.update!(image_key: final_key)
      begin
        IconStorage.delete(staged_key)
      rescue StandardError => e
        Rails.logger.warn("[difficulty_drafts] orphaned staged image #{staged_key}: #{e.message}")
      end
    end

    def cleanup_canonical_image(record)
      return if record.image_key.blank?

      IconStorage.delete(record.image_key)
    rescue StandardError => e
      # A missing canonical image shouldn't block destroying the row.
      Rails.logger.warn("[difficulty_drafts] failed to delete canonical image #{record.image_key}: #{e.message}")
    end

    def remove_temp_images(drafts)
      drafts.each do |draft|
        next unless draft.target_type == 'Difficulty'

        key = draft.attributes_payload&.dig('image_key')
        next unless key.is_a?(String) && key.start_with?("#{IMAGE_DRAFT_PREFIX}/")

        begin
          IconStorage.delete(key)
        rescue StandardError => e
          Rails.logger.warn("[difficulty_drafts] failed to delete temp image #{key}: #{e.message}")
        end
      end
    end

    # Accepts a raw PNG byte string or a base64-encoded string. Base64 input
    # always comes through JSON as UTF-8, so the byte-pattern fast-path below
    # has to compare on the binary view to avoid Encoding::CompatibilityError.
    def decode_image(image_data)
      return '' if image_data.blank?
      return image_data if image_data.is_a?(String) && image_data.b.start_with?(IconUploadValidator::PNG_SIGNATURE)

      Base64.decode64(image_data.to_s)
    end
  end
end
