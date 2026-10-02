# Classic III catalogue migration

Promotion `ClassicIII` uses ID 12; IDs 1–11 keep their meanings. Deploy the matching web option/label before exposing the catalogue value to editors.

The reviewed manifest in `db/data/manifests/classic_iii.csv` contains 44 SSR character weapons, 23 SSR summons, 139 R/SR weapons and 45 R/SR summons. SSR membership comes from explicit published lists, not release dates: local summon dates contain known same-name character import errors. Weapon membership resolves the verified character through its recruitment ID. R/SR entries are existing Premium catalogue items released before 2026-03-10, excluding limited equipment; Water Balloons is excluded.

Exclusive SSR entries lose ordinary draw availability (Premium, Flash, Legend, Valentine, Summer, Halloween, Holiday: IDs 1, 4–9) and gain 12. Other promotions, including Classic I/II, Collab, Formal and unknown values, remain. Shared SSR summons and R/SR entries retain all existing promotions and gain 12. The 15 shared SSR summons are six Archangels, six Crests, Belial, Gorilla and Demonbream. Membership does not imply ordinary Vermilion spark eligibility: Archangels and Belial are excluded from ordinary exchange, while the special Step Up permits them.

Sources checked 2026-10-02:

- https://gbf.wiki/SSR_Characters_List#Classic_Draw_III
- https://gbf.wiki/SSR_Summons_List#Classic_Draw_III
- https://gbf.wiki/Draw#Classic_III
- https://xn--bck3aza1a2if6kra4ee0hf.gamewith.jp/article/show/547972
- https://xn--bck3aza1a2if6kra4ee0hf.gamewith.jp/article/show/440216

This is corroborated wiki/guide membership, not an in-game rate-table export. Wiki summary exceptions are incomplete; the explicit lists and individual Belial page establish the shared memberships.

## Review and apply

Supply an explicit `DATABASE_URL` for the intended environment. Review without writes:

```sh
bundle exec rails runner 'require Rails.root.join("db/data/20261002000001_assign_classic_iii_promotions"); puts JSON.pretty_generate(AssignClassicIiiPromotions.new.preview)'
```

The normal deployment runs `db:migrate:with_data`. The migration locks the two catalogue tables while resolving and updating the manifest, validates unique identifiers, exact rarity and known recruitment IDs, and fails before updates if any required entry is missing or ambiguous. Preview shows before/after arrays. Repeating the migration produces no further changes. Rollback is irreversible because prior availability varies per item; take and retain the normal database backup before deployment.

The obsolete `gacha:migrate_promotions` backfill refuses writes whenever catalogue promotions are populated. Its `TEST=true` preview remains available. Legacy gacha flags cannot represent Classic III and must not overwrite authoritative arrays. Default wiki population fills only empty arrays; `OVERWRITE=true` is a separate explicit catalogue refresh and should use current source data.

Validation used an isolated disposable PostgreSQL test database with catalogue fields only; no writes to existing databases, deployments or pushes occurred. The manifest was independently checked for exact IDs and availability. Targeted migration tests cover reruns, unrelated rows/promotions, shared exceptions, missing and duplicate IDs.
