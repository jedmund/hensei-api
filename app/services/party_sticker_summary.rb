# frozen_string_literal: true

# Batched sticker lookups for rendering parties. Rendering many parties
# computes labels and the viewer's own stickers for all of them in one grouped
# query each (PartyBlueprint does this itself; see `batch_options`).
module PartyStickerSummary
  module_function

  # { party_id => [slug] }: each party's label, the active sticker given most
  # among its last RECENT_FOR_LABEL active stickers (by when each was first
  # given). Retired stickers don't take up any of those places. A tie is broken
  # by a hash of the party and slug: as good as random, but the same on every
  # load, so cards don't change sticker when lists refetch.
  def labels_for(party_ids)
    ids = Array(party_ids).compact.uniq
    return {} if ids.empty?

    label_rows(PartySticker.where(party_id: ids))
      .pluck(:party_id, :slug)
      .to_h { |party_id, slug| [party_id, [slug]] }
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

  # [{ sticker: slug, count: n, meaning: { en, ja }, image_url, image_url_ja }] for one
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
               image_url: Api::V1::StickerBlueprint.image_url(sticker),
               image_url_ja: Api::V1::StickerBlueprint.image_url(sticker, :image_key_jp)
             }
           end
  end

  # Subquery of the ids of parties whose label is `slug`.
  def labelled_party_ids(slug)
    label_rows(PartySticker.all).where(slug: slug.to_s).select(:party_id)
  end

  # One row (party_id, slug) per party in `scope`: its label. Ranks each
  # party's active stickers newest first, counts slugs among the most recent,
  # and keeps the most counted, ties broken by the hash.
  def label_rows(scope)
    recent = scope.joins(:sticker)
                  .where(stickers: { active: true })
                  .select(
                    'party_stickers.party_id', 'stickers.slug',
                    'ROW_NUMBER() OVER (PARTITION BY party_stickers.party_id ' \
                    'ORDER BY party_stickers.created_at DESC, party_stickers.id DESC) AS recency'
                  )
    labels = PartySticker.unscoped
                         .from(recent, :party_stickers)
                         .where('party_stickers.recency <= ?', PartySticker::RECENT_FOR_LABEL)
                         .group(:party_id, :slug)
                         .select('DISTINCT ON (party_stickers.party_id) party_stickers.party_id, party_stickers.slug')
                         .order(Arel.sql(
                                  'party_stickers.party_id, COUNT(*) DESC, ' \
                                  "md5(party_stickers.party_id::text || ':' || party_stickers.slug)"
                                ))
    # Wrapped, so plucking or selecting from it keeps the DISTINCT ON
    PartySticker.unscoped.from(labels, :party_stickers)
  end

  # PartyBlueprint options with every party's labels and the viewer's
  # stickers looked up at once.
  def batch_options(parties, viewer)
    ids = parties.map(&:id)
    { party_labels: labels_for(ids), my_stickers: my_stickers_for(viewer, ids) }
  end
end
