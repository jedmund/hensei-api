# frozen_string_literal: true

# Batched sticker lookups for rendering parties. List pages compute labels and
# the viewer's own stickers for the whole page in one grouped query each, and
# pass the results to PartyBlueprint as options (see `blueprint_options`).
module PartyStickerSummary
  module_function

  # { party_id => [slug, slug] }: active stickers given by at least
  # STICKER_LABEL_THRESHOLD users, most given first, at most MAX_LABELS.
  def labels_for(party_ids)
    ids = Array(party_ids).compact.uniq
    return {} if ids.empty?

    counts = PartySticker.joins(:sticker)
                         .where(party_id: ids, stickers: { active: true })
                         .group(:party_id, 'stickers.slug', 'stickers.position')
                         .having('COUNT(*) >= ?', PartySticker::STICKER_LABEL_THRESHOLD)
                         .count

    counts.group_by { |(party_id, _slug, _position), _count| party_id }
          .transform_values do |rows|
            rows.sort_by { |(_pid, slug, position), count| [-count, position, slug] }
                .first(PartySticker::MAX_LABELS)
                .map { |(_pid, slug, _position), _count| slug }
          end
  end

  # [{ id:, sticker: slug, mine:, placement: { x, y, rotation } | nil }] for
  # every active sticker given to the party, oldest first. Givers stay
  # anonymous. For the sticker area.
  def placed_for(party_id, viewer)
    PartySticker.joins(:sticker)
                .where(party_id: party_id, stickers: { active: true })
                .order(:created_at, :id)
                .pluck(:id, 'stickers.slug', :user_id, :x, :y, :rotation)
                .map do |id, slug, user_id, x, y, rotation|
                  {
                    id: id,
                    sticker: slug,
                    mine: viewer.present? && user_id == viewer.id,
                    placement: x.nil? || y.nil? ? nil : { x: x, y: y, rotation: rotation }
                  }
                end
  end

  # { party_id => slug } for the stickers `user` gave, including retired ones.
  def my_stickers_for(user, party_ids)
    ids = Array(party_ids).compact.uniq
    return {} if user.nil? || ids.empty?

    PartySticker.joins(:sticker)
                .where(user_id: user.id, party_id: ids)
                .pluck(:party_id, 'stickers.slug')
                .to_h
  end

  # [{ sticker: slug, count: n, meaning: { en, ja }, image_url }] for one
  # party, retired stickers included (they still count, and the picker
  # catalogue no longer lists them, hence meaning and image here). Only ever
  # shown to the party's owner.
  def breakdown_for(party_id)
    counts = PartySticker.where(party_id: party_id).group(:sticker_id).count
    return [] if counts.empty?

    Sticker.where(id: counts.keys)
           .sort_by { |sticker| [-counts[sticker.id], sticker.position, sticker.slug] }
           .map do |sticker|
             {
               sticker: sticker.slug,
               count: counts[sticker.id],
               meaning: { en: sticker.meaning_en, ja: sticker.meaning_jp },
               image_url: Api::V1::StickerBlueprint.image_url(sticker)
             }
           end
  end

  # Subquery of party ids where `slug` (an active sticker) has reached the
  # label threshold.
  def labelled_party_ids(slug)
    PartySticker.joins(:sticker)
                .where(stickers: { slug: slug.to_s, active: true })
                .group(:party_id)
                .having('COUNT(*) >= ?', PartySticker::STICKER_LABEL_THRESHOLD)
                .select(:party_id)
  end

  # Options to pass to PartyBlueprint when rendering many parties.
  def blueprint_options(parties, current_user)
    ids = parties.map(&:id)
    {
      current_user: current_user,
      party_labels: labels_for(ids),
      my_stickers: my_stickers_for(current_user, ids)
    }
  end
end
