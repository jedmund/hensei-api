# frozen_string_literal: true

module PartyDifficulty
  ##
  # Per-editor staging layer for difficulty rules / tiers / components.
  # Editors mutate state here via the controllers, hit Preview to validate,
  # iterate, and explicitly commit. Other consumers (the public list, the
  # background score sweep) keep reading the canonical tables.
  class DraftWorkspace
    EDITABLE_COLUMNS = {
      'Difficulty' => %w[name slug description min_score max_score sort_order color].freeze,
      'DifficultyRule' => %w[name description component rule_type params weight active].freeze,
      'DifficultyComponent' => %w[weight enabled min_count_to_score target_max].freeze
    }.freeze

    SUMMARY_COLUMNS = {
      'Difficulty' => %w[name slug min_score max_score sort_order color],
      'DifficultyRule' => %w[name component rule_type weight active],
      'DifficultyComponent' => %w[name weight enabled min_count_to_score target_max]
    }.freeze

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
        # Each apply! triggers the per-record after_save :bump_ruleset_version
        # callback on Difficulty / DifficultyRule / DifficultyComponent, so the
        # version increases by N. The log records the final post-apply version;
        # we don't add an extra explicit bump here.
        @drafts.each { |draft| apply!(draft) }
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
      destroyed = DifficultyDraft.for_user(@user).destroy_all
      @drafts = []
      destroyed.size
    end

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
        draft = DifficultyDraft.find_or_initialize_by(
          user: @user,
          target_type: target_type,
          target_id: target_id
        )
        draft.operation = operation
        draft.attributes_payload = operation == 'destroy' ? {} : payload
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

      drafts.each do |draft|
        case draft.operation
        when 'create'
          creates << {
            draft_id: draft.id,
            attributes: sanitize_attributes(target_type, draft.attributes_payload)
          }
        when 'update'
          target = draft.target
          next unless target

          field_diff = compute_field_diff(target, draft.attributes_payload, target_type)
          next if field_diff.empty?

          updates << {
            draft_id: draft.id,
            target_id: target.id,
            label: summary_label(target),
            changes: field_diff
          }
        when 'destroy'
          target = draft.target
          next unless target

          destroys << {
            draft_id: draft.id,
            target_id: target.id,
            label: summary_label(target),
            snapshot: target.attributes.slice(*SUMMARY_COLUMNS.fetch(target_type, []))
          }
        end
      end

      { creates: creates, updates: updates, destroys: destroys }
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
        klass.create!(sanitize_attributes(draft.target_type, draft.attributes_payload))
      when 'update'
        target = draft.target
        target&.update!(sanitize_attributes(draft.target_type, draft.attributes_payload))
      when 'destroy'
        draft.target&.destroy!
      end
    end
  end
end
