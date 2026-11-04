# frozen_string_literal: true

module PartyDifficulty
  class DraftWorkspace
    ##
    # One section's (tiers', rules' or components') pending drafts compared with the
    # canonical rows they target: what each create adds, each update changes and
    # each destroy removes, and which drafts are stale.
    class Diff
      def initialize(target_type, drafts)
        @target_type = target_type
        @drafts = drafts
      end

      def to_h
        creates = []
        updates = []
        destroys = []
        @drafts.each do |draft|
          case draft.operation
          when 'create' then creates << create_entry(draft)
          when 'update' then update_entry(draft)&.then { |entry| updates << entry }
          when 'destroy' then destroys << destroy_entry(draft)
          end
        end

        { creates: creates, updates: updates, destroys: destroys }
      end

      private

      # Every update/destroy target, loaded in one query.
      def targets_by_id
        @targets_by_id ||= begin
          target_ids = @drafts.filter_map { |d| d.target_id unless d.operation == 'create' }.uniq
          target_ids.any? ? @target_type.constantize.where(id: target_ids).index_by(&:id) : {}
        end
      end

      def create_entry(draft)
        {
          draft_id: draft.id,
          attributes: DraftWorkspace.sanitize_attributes(@target_type, draft.attributes_payload)
        }
      end

      # nil when the update changes nothing.
      def update_entry(draft)
        target = targets_by_id[draft.target_id]
        return stale_entry(draft) if target.nil?

        field_diff = compute_field_diff(target, draft.attributes_payload)
        return if field_diff.empty?

        {
          draft_id: draft.id,
          target_id: target.id,
          label: summary_label(target),
          changes: field_diff,
          stale: stale_against?(target, draft)
        }
      end

      def destroy_entry(draft)
        target = targets_by_id[draft.target_id]
        return stale_entry(draft) if target.nil?

        {
          draft_id: draft.id,
          target_id: target.id,
          label: summary_label(target),
          snapshot: target.attributes.slice(*SUMMARY_COLUMNS.fetch(@target_type, [])),
          stale: stale_against?(target, draft)
        }
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

      def compute_field_diff(record, proposed)
        allowed = EDITABLE_COLUMNS[@target_type] || []
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
    end
  end
end
