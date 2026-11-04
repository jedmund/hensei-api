# frozen_string_literal: true

module PartyDifficulty
  class DraftWorkspace
    ##
    # A tier draft's icon: staged under a draft-scoped key, promoted to the
    # tier's canonical key on commit, and removed when the draft goes away.
    module Images
      module_function

      # Uploads the bytes to a draft-scoped S3 key and records that key on the
      # draft's attributes so commit! can promote it to the canonical key once the
      # tier's id is known.
      def stage!(draft, image_data:, filename: nil)
        decoded = decode(image_data)
        result = IconUploadValidator.call(decoded)
        raise ImageValidationError, result.error unless result.valid?

        key = "#{IMAGE_DRAFT_PREFIX}/#{draft.id}.png"
        IconStorage.put(key, decoded)

        payload = (draft.attributes_payload || {}).merge('image_key' => key)
        payload['image_filename'] = filename if filename.present?
        draft.update!(attributes_payload: payload)
        draft
      end

      # When a draft has a `_drafts/`-prefixed image_key in its attributes, copy
      # the staged S3 object to the canonical key and write that key to the row.
      #
      # Ordering matters for retry safety: copy → update_column → best-effort
      # delete. If the DB write fails, the canonical key exists but the row
      # doesn't reference it (orphan, recoverable). If the delete fails, the
      # staged copy lingers — that's intentionally non-fatal, the S3 lifecycle
      # rule on the `_drafts/` prefix sweeps it.
      def promote(draft, record)
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

      def delete_canonical(record)
        return if record.image_key.blank?

        IconStorage.delete(record.image_key)
      rescue StandardError => e
        # A missing canonical image shouldn't block destroying the row.
        Rails.logger.warn("[difficulty_drafts] failed to delete canonical image #{record.image_key}: #{e.message}")
      end

      def delete_staged(drafts)
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
      def decode(image_data)
        return '' if image_data.blank?
        return image_data if image_data.is_a?(String) && image_data.b.start_with?(IconUploadValidator::PNG_SIGNATURE)

        Base64.decode64(image_data.to_s)
      end
    end
  end
end
