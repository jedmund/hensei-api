# Element, proficiency and race renumbering

Status: **ready to deploy.** Data migration `20261024120000_renumber_enums_to_game_ids`
moves element, proficiency and race to the game's own numbers, so payloads from the game and
the game CDN's file names need no conversion table.

| | Old | New (the game's) |
|---|---|---|
| Element | 1 Wind, 2 Fire, 3 Water, 4 Earth, 5 Dark, 6 Light | 1 Fire, 2 Water, 3 Earth, 4 Wind, 5 Light, 6 Dark |
| Proficiency | 3 Axe, 4 Spear, 5 Bow, 6 Staff, 8 Harp, 9 Gun | 3 Spear, 4 Axe, 5 Staff, 6 Gun, 8 Bow, 9 Harp |
| Race | 0 Unknown, 5 Primal, 6 None | 5 Other, 6 Primal (None folds into Other) |

Null element and None proficiency stay 0; Sabre, Dagger, Melee, Katana and races 1–4 and
7–10 don't move. Support summon sections follow the element numbers, with Misc at 0.

## What changes where

- **Database:** every integer element/proficiency/race column, `support_summons.section`,
  the race lists in `weapon_skill_effects.condition`, the keys of
  `weapons.element_variant_ids`, Solomonis proficiency targets (race targets were already
  the game's) and the element/proficiency in rich-text mention tokens. One transaction;
  `down` reverses it except the race clean-up (None/Unknown → Other, stray `race2 = 0`).
- **Committed data:** the curation snapshot and parity baseline (race lists), seed CSVs,
  the Solomonis seed and the golden fixtures are already converted. The curation drift
  check is clean against a migrated database.
- **Bucket:** files whose names carry one of these numbers swap names (see below).
- **Clients:** hensei-web, hensei-extractor and siero-bot (which reads `element` straight
  from the database) each have a matching change.
- **Old extension builds** send their sync filter as `elements` / `proficiencies` in our
  old numbers. `CollectionImportFilter` converts those; current builds send
  `element_ids` / `proficiency_ids`. Remove the legacy keys once old builds are gone.

## Order

1. **Ahead of time:** ship the hensei-web version polling (`kit.version.pollInterval` and
   the `beforeNavigate` reload in the root layout) on its own, a few days early. A tab only
   reloads onto a new build if it already runs the polling, and a stale tab would send
   old numbers on writes.
2. **Stage the images** from a local checkout whose `hensei_dev` has the migration applied.
   Never point `DATABASE_URL` at production for this. Staged copies go under
   `tmp/renumber-enums/` and change nothing the site reads.

   ```
   bin/rails granblue:renumber_enum_images step=plan    # writes tmp/renumber_enum_images_plan.json
   bin/rails granblue:renumber_enum_images step=stage
   ```

3. **Deploy together:** hensei-api (the pre-deploy `db:migrate:with_data` runs the
   migration, then the curation sync, which has nothing to do), hensei-web and siero-bot.
4. **Right after:** `step=apply`, then check element-changeable weapons, Lyria-style
   characters, mastery icons, gauph keys and weapon-skill icons on the site. The web and
   extension add `?ids=game` to those URLs, so browsers don't show copies cached under the
   old names.
5. **Once the site looks right:** `step=cleanup` deletes the staged copies. The bucket has
   no versioning, so keep them until then.
6. **Last:** merge hensei-extractor to `main` (that submits it to the Chrome Web Store).
   An old API would ignore the new filter keys and reconcile a sync without its filter.

## Renamed files

About 3,000 files (`step=plan` lists them):

```
icons/mastery/ele-{element}.png
weapons/keys/gauph-*-{proficiency}.png
weapons/{main,grid,square,base,gacha}/{id}_{element}.{jpg,png}    element-changeable weapons
characters/{size}/{id}_{pose}_0{element}[_{gender}].{jpg,png}     null-element characters
icons/weapon-skills/{en,ja}/{stem}.png                            element-wildcard skill icons
```
