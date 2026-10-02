# Supplied banner catalogue reconciliation

This migration uses the user's 2026-10-02 in-game response projection as a reviewed 571-item identity manifest. It creates 20 R and 50 SR weapons, assigns Premium membership to 61 existing lower-rarity weapons, one ordinary SSR weapon and eight SSR summons, and repairs Reunion's explicit Flash availability while removing its erroneous Classic II flag. All existing UUIDs and unrelated memberships remain. No probability or rate-up configuration changes are included.

The new item names, game element and weapon kind come directly from the supplied game response. Explicit mappings convert game rarity 2/3 to Hensei 1/2, game element {1:2,2:3,3:4,4:1,5:6,6:5}, and game weapon kind {1:1,2:2,3:4,4:3,5:6,6:9,7:7,8:5,9:8,10:10}. Recruitment matches exact canonical names after removing only a final rarity or element disambiguation suffix, with the same rarity, translated element, and no season. Exactly one distinct Granblue ID is required; the reviewable manifest records catalogue names and matched IDs. Twelve non-character weapons have no recruit. Unknown Japanese names, weapon release dates and stats remain unknown.

Reunion's local raw wiki source explicitly says `obtain=premium,gala,normal`; the existing parser maps `gala` to Flash (4). Its recruitment ID and obtain text are checked before changing its flags. The source response is a particular 6% banner and does not establish new universal Gala or Classic memberships for other items. New weapons initially receive Premium (1) only. Shared Classic lower-rarity reconciliation requires separately reviewed pre-cutoff evidence.

## Preview and deployment

Use an explicit target `DATABASE_URL` with:

```sh
bundle exec rails granblue:preview_banner_catalogue
```

The task reads catalogue rows only and prints create/update plans. The migration locks weapons, summons and characters, resolves every identifier before writes, rejects missing/duplicate IDs and metadata drift, validates recruitment/rarity, and protects Classic III SSR exclusions. Actual deployment runs the normal `db:migrate:with_data`. Missing production metadata or source drift blocks the whole migration. Take the normal backup; rollback is irreversible because created weapons may gain collection references.

This change does not require the pending Classic III/rate-up migrations to execute; version `20261002020001` follows their versions chronologically. When combining branches, regenerate `db/data_schema.rb` after applying all migrations so each history entry is present, rather than relying on its maximum alone.

Validation: 3,221 examples, zero failures, two pending, coverage 81.55%; changed files pass Rubocop. The migration has six focused examples covering preview, preservation, canonical recruits, reruns, missing metadata/recruits, duplicate IDs, drift and Classic SSR exclusions. The focused-only run passes but exits 2 because of the repository SimpleCov minimum. Actual `data:migrate:up` and `data:dump` ran against a catalogue-only disposable PostgreSQL database; all 571 identities resolve after migration and a second apply preserves UUIDs and arrays.

Existing application databases were read only; no production writes, deployment or push occurred. Production still requires the explicit preflight against its actual catalogue. Classic lower-rarity completeness is a separate followup, not inferred from this ordinary banner sample.

## Shared lower rarities in Classic I, II and III

Followup migration `20261002020002` adds promotions 2, 3 and 12 to all 315 ordinary lower-rarity items in the supplied catalogue manifest. Premium and other existing memberships remain. The common cutoff is strictly before 2026-03-10, as stated for all three pools in https://gbf.wiki/Draw.

Evidence is explicit in `db/data/manifests/classic_lower_catalogue.json`: 245 existing items have catalogue release dates before the cutoff; 58 newly created recruitment weapons correspond to canonical characters released by 2019-09-30; 12 non-character weapons appear in exact wiki revisions from 2019-10-30/31 whose IDs and rarity match. Historical existence establishes eligibility without inventing an exact weapon release date. The preflight validates catalogue/character date drift and recruitment identifiers, rejects SSR and missing ordinary membership, and resolves all rows before writes. Run `granblue:preview_classic_lower_catalogue` against an explicit database to review the arrays.

The followup requires the ordinary catalogue migration first and the Classic III enum/reader changes before use by clients. All 315 shared lower memberships and rerun stability were validated using the real data migration task in a dedicated catalogue-only smoke database. The final full suite, including both reconciliation services, passed 3,226 examples with zero failures and two pending; coverage was 81.59%. Five changed files pass Rubocop; 26 focused examples pass with coverage above the repository minimum.
