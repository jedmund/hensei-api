# Populating character skill effects from game data

**Status:** Phase 0 (measurement) done + Status catalog rebuilt. Phase 1 planned, not started.
**Branch:** `feat/skill-effects-from-game-data` (off `origin/staging`).

## Why

`skill_effects` rows are currently produced by the **prose parser** — `Granblue::Parsers::CharacterSkills::EffectParser` reads the English wiki description and matches statuses **by name**. It's heuristic and incomplete. Now that ~967 characters have `game_raw_en` (from the Dataminer backfill), the game's structured ability fields are a far more accurate effect source.

Goal (per product): effects should serve **display (UI chips/icons), querying/filtering, computation (FA/damage), and data-completeness** — so the precision bar is computation-grade, which means **game data becomes the authoritative source**, with prose only as a fallback for the handful of characters without game data (the 6 playable collabs that aren't in the archive + some NPCs).

## What game data gives us (per ability/ougi/support)

`CharacterWikiData#game_action(key)` returns the ability blob with positionally-aligned CSV arrays — one effect per index:

| Game field | → `skill_effects` column |
|---|---|
| `ailment` (ailment IDs, e.g. `1010002005,...`) | `status_id` via `statuses.game_ailment_id` (**already wired**) |
| `type` (e.g. `attack_down,defense_down`) | `effect_type` / classification (also a **name fallback** — see Phase 1) |
| `target1`/`target2` (`them/one`, `me`, `all`) | `target` |
| `param_min`/`param_max` | `amount` / `amount_max` |
| `turn` / `second` | `duration_value` + `duration_unit` |
| `rate` | `accuracy` |
| `state` | stacking / level |
| `recast` | (already `cooldown`) |

`skill_effects` already has the columns for this: `effect_type, target, amount, amount_max, duration_value, duration_unit, accuracy, stacking_frame, damage_pct, hit_count, damage_cap, damage_element, heal_pct, heal_cap, status_id, ordinal`. So this is a **parser + decode** effort, not a schema rebuild.

## Phase 0 findings (measurement)

Measured prose-parsed effects vs game `ailment` IDs across all game-data characters (967 chars, 4,874 versions with game ailments, **11,255 game ailment-effect occurrences**). Strict **exact-ID** comparison.

| Metric | Before catalog rebuild | After catalog rebuild |
|---|---|---|
| Captured by prose | 860 (7.6%) | 1,137 (10.1%) |
| **Missed but in catalog (game-join wins)** | 7,690 | **8,650** |
| Missed, **not** in catalog | 2,705 | **1,468** |
| Distinct catalog-gap ailment IDs | 1,401 | **877** |
| prose status effects / unbacked-by-game | 5,438 / 4,564 | 6,335 / 5,166 |

- **Resolvable to a Status after rebuild = 1,137 + 8,650 = 9,787 / 11,255 ≈ 87%.** A game-data parser would populate these accurately via the `ailment → status` join immediately, vs prose's fuzzy ~10%.
- `prose_unbacked` (~5,166) confirms this is a **replacement**, not an augmentation — game effects will differ substantially from today's prose effects. Needs validation.
- **Caveat:** exact-ID comparison is strict — some "misses" / "unbacked" are the *same effect at a different status-row granularity* (prose matched "ATK Up" → one row; game uses a specific ATK Up ID). So prose isn't literally 90% wrong; the direction (game >> prose) is what's solid.

Non-ailment sizing: `type` entries total 13,919 vs 11,255 ailment occurrences → ~2,664 (~19%) are non-ailment (damage/heal/plain stat) = **Phase 2** territory. ~81% are ailment-bearing (the join path).

## Status catalog rebuild (done)

Re-ran `granblue:build_status_catalog` against the now-expanded game data (`StatusCatalogBuilder.build_all` reads `game_action['ailment']` across all chars and `find_or_initialize_by(game_ailment_id)`).

- Statuses **2,376 → 2,935** (ailment-ID-bearing **748 → 1,272**, created 559 / updated 156).
- Closed ~46% of the catalog gap (occurrences 2,705 → 1,468; distinct IDs 1,401 → 877).

## Phase 1 plan (next)

1. **Close the remaining 877 catalog gaps** — they failed because the builder pairs ailment IDs with **names** positionally and ran out of names. The game ability `type` field is positionally aligned with `ailment`, so add a **`type`-slug → name fallback** in `StatusCatalogBuilder` (e.g. `attack_down` → "ATK Down") when no better name exists. Rebuild + re-measure; expect status-effect coverage → ~100%.
2. **Game-effect parser** — a `GameEffectParser` (parallel to `EffectParser`) that builds effects per version from `data.game_action(key)` using the field map above. Map base slots first; variants (enhanced/transform/option/form) pull from `appear_ability` / `power_up_special_skill` / nested `display_action_ability_info.action_ability` — do those second.
3. **Precedence** — game-primary where game data exists (967 chars), prose fallback for the rest. Re-persist via `granblue:parse_character_skills`.
4. **Validation** — the cross-validation report (`Reporter#cross_validate_statuses`) flips into a game-vs-prose diff; golden snapshot guards regressions; spot-check ~10 well-understood characters.

## Phase 2 (later)

Non-ailment effects: damage (`deal_damage`, `damage_pct`/`hit_count`/`damage_cap`/`damage_element`), heal (`heal_pct`/`heal_cap`), dispel, and plain stat buffs without ailment IDs — driven by `type` slugs that have no `ailment` entry. Plus **damage scaling** (we currently store only headline caps) — needed for FA/damage computation; this is the gnarliest encoding.

## Key code seams / where things live

- `lib/granblue/parsers/character_wiki_data.rb` — `#game_action(key, lang:)` → the ability blob; `#csv`.
- `lib/granblue/parsers/character_skills/effect_parser.rb` — current prose effect parser.
- `lib/granblue/parsers/character_skills/reporter.rb` — `#cross_validate_statuses` already reads game `ailment` IDs per version and diffs vs parsed (`status_ailment_id` maps `status_id → game_ailment_id`). This is the seam Phase 0 is built on and the validation hook.
- `lib/granblue/parsers/status_catalog_builder.rb` — `build_all`; `build_paired_records(names, ailment_ids, …)` is where the `type`-slug name fallback goes.
- `lib/granblue/parsers/character_skills/builder.rb` — `version_attrs` builds the per-version graph; `source_key` maps a version back to its `game_action`.
- `statuses` table — `game_ailment_id` (unique), `name_en`, `family`, `level`, `category`, `icon` (icons exist → usable for UI chips).
- Frontend: effects are serialized (`SkillEffectBlueprint` inside `CharacterSkillVersionBlueprint`) but **not rendered** yet — display is a separate `hensei-web` workstream once data is solid.

## How to re-measure (Phase 0 script)

Read-only. Run after the catalog `type`-slug fallback to confirm coverage. `bin/rails runner <<'RUBY' … RUBY`:

```ruby
parser = Granblue::Parsers::CharacterSkillParser
lookup = parser.build_status_lookup
by_ailment = Status.where.not(game_ailment_id: nil).index_by(&:game_ailment_id)
chars = 0; vers = 0; g_total = 0; captured = 0; missed = 0; missed_in_cat = 0; not_in_cat = 0
Character.where.not(wiki_raw: [nil, '']).where.not(game_raw_en: nil).find_each do |c|
  data = Granblue::Parsers::CharacterWikiData.new(c)
  graph = parser.new(c, status_lookup: lookup).parse(persist: false)
  chars += 1
  graph[:slots].each do |slot|
    slot[:versions].each do |v|
      ga = data.game_action(v[:source_key]); next unless ga
      ailments = data.csv(ga['ailment']); next if ailments.empty?
      vers += 1
      parsed = v[:effects].filter_map { |e| e[:status_id] && lookup[:by_id][e[:status_id]]&.game_ailment_id }
      ailments.each do |aid|
        g_total += 1
        if parsed.include?(aid) then captured += 1
        else missed += 1; by_ailment.key?(aid) ? missed_in_cat += 1 : not_in_cat += 1 end
      end
    end
  end
end
puts "chars=#{chars} versions=#{vers} game_ailments=#{g_total}"
puts "captured=#{captured} missed_in_catalog=#{missed_in_cat} missed_not_in_catalog=#{not_in_cat}"
puts "resolvable=#{captured + missed_in_cat} (#{(100.0 * (captured + missed_in_cat) / g_total).round(1)}%)"
RUBY
```

## Open decisions

- Confirm the exact semantics of `type`, `target1`/`target2`, `turn` vs `second`, `param_min`/`max`, `state`, `multi` across many abilities before trusting them computation-grade (Phase 1 decode step).
- Whether to keep prose effects at all for game-data characters, or fully replace.
- How to handle the ~6 playable collabs + NPCs with no game data (prose-only, lower fidelity — likely acceptable).
