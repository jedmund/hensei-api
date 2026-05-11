# Party Difficulty — Deferred Follow-Ups

Items surfaced during code review of the stacked `party-difficulty-*` PRs that were intentionally deferred. Each entry includes where the deferral was decided and what a future change should do.

---

## Consolidate `IconStorage` / `IconUploadValidator` with `UploadedImageService`

**Status:** deferred until after PR #414 (substitutions feature) merges. Tracked separately as a unification follow-up so both features get fixed before the consolidation happens.

**What.** `-tier-images` introduced two service objects:

- `app/services/icon_storage.rb` — S3 vs local backend branching, `put` / `copy` / `delete`, hardcoded `image/png` content type.
- `app/services/icon_upload_validator.rb` — magic-byte PNG sniff, size cap, MiniMagick dimension check.

PR #414 plans to introduce `UploadedImageService` (per `.context/attachments/pasted_text_2026-05-10_22-38-31.txt` — the R5 plan) covering the same surface: validate / store / delete for small PNG icons, configurable per-call.

**What to do (after #414 lands).** Migrate `DraftWorkspace#attach_image!` / `promote_image_if_present` / `cleanup_canonical_image` / `remove_temp_images` to use `UploadedImageService` directly. Delete `IconStorage` and `IconUploadValidator`. Move the `_drafts/` prefix discipline into `DraftWorkspace` (the prefix is difficulty-specific; `UploadedImageService` should stay generic).

**Why not consolidated upfront.** PR #414 isn't merged yet. Doing this stack first lets each feature land independently with its own review; unification is a follow-up PR off `main` after both ship.

**Files to touch (later).**
- Delete: `app/services/icon_storage.rb`, `app/services/icon_upload_validator.rb`.
- Modify: `app/services/party_difficulty/draft_workspace.rb` (replace direct calls).
- Add: `spec/services/uploaded_image_service_spec.rb` already in #414's plan; difficulty-side specs reuse it.

**When to revisit.** When PR #414 merges to `main`.

---

## Cache ruleset reads in `Calculator`

**Status:** deferred during review of `jedmund/party-difficulty-admin`.

**Symptom.** `Calculator#initialize` reads four tables on every invocation:
- `DifficultyRule.active.to_a`
- `DifficultyComponent.all.to_a`
- `Difficulty.ordered.to_a`
- `DifficultyConfig.current_version`

These reads fire from `ScoreJob`, `SweepJob`, and `DifficultyPreviewsController#create`. They produce identical results across every call within a ruleset version, but are re-fetched each time.

**What to do.** Wrap the four defaults in `Rails.cache.fetch` keyed by `DifficultyConfig.current_version`. The version bumps on every relevant save (`after_save :bump_ruleset_version` on `Difficulty`, `DifficultyRule`, `DifficultyComponent`) plus explicitly in the two `update_all` calibration migrations, so the cache key changes automatically when the ruleset changes — no manual invalidation needed.

Sketch:

```ruby
def initialize(party, rules: nil, components: nil, difficulties: nil, ruleset_version: nil)
  @party = party
  @ruleset_version = ruleset_version || DifficultyConfig.current_version
  @rules = rules || Rails.cache.fetch(["pd_rules", @ruleset_version]) { DifficultyRule.active.to_a }
  @components = components || Rails.cache.fetch(["pd_components", @ruleset_version]) { DifficultyComponent.all.to_a }
  @difficulties = difficulties || Rails.cache.fetch(["pd_difficulties", @ruleset_version]) { Difficulty.ordered.to_a }
end
```

**Why not in the original stack.** The win is real but small at ~30 rules. Editor-only access mitigates abuse on the preview endpoint, so this is not a merge blocker. Cache code is also a new failure mode (Marshal serialization of ActiveRecord, `:null_store` vs `:memory_store` test-env nuance) that should be motivated by a measured symptom, not a code smell.

**Files to touch.**
- `app/services/party_difficulty/calculator.rb:30` — has a `TODO(party-difficulty-perf)` pointer.
- `app/controllers/api/v1/difficulty_previews_controller.rb:20` — has a matching pointer.

**When to revisit.** When rule count grows past ~100, or when editor preview latency becomes a noticeable complaint.

---

## Reconcile `draft.id` ↔ canonical id after a create-draft commit

**Status:** deferred during review of `jedmund/party-difficulty-drafts`.

**Symptom.** `DraftWorkspace#build_created` assigns `record.id = draft.id` so the frontend can address a pending-creation row before it commits. After commit, `apply!` does `klass.create!(...)`, which generates a fresh UUID — the canonical id differs from the draft id the frontend just used.

**Why not in the stack.** Verified that the Svelte frontend (`accra-v2` worktree) does not yet have a difficulty draft UI. There is currently no consumer that could observe the mismatch. The bug is latent.

**What to do (when the UI is built).** Return a `{ draft_id => canonical_id }` map in the commit response. The frontend can reconcile any locally-cached references. Backwards-compatible — additive field on the existing JSON response. Sketch:

```ruby
# DraftWorkspace#commit!
created_id_map = {}
@drafts.each do |draft|
  if draft.operation == 'create'
    record = apply!(draft)
    created_id_map[draft.id] = record.id
  else
    apply!(draft)
  end
end
# include created_id_map in the return value alongside the change log
```

**When to revisit.** When the difficulty draft UI is added to `hensei-svelte`.

---

## Request specs for the difficulty admin endpoints

**Status:** deferred per the original review plan (R3 routing).

**What.** No request specs exist for any of the four new controllers added in `-admin`, nor for `DifficultyDraftsController` added in `-drafts`.

**What to do.** Add request specs covering: auth branch (non-editor → 401), happy path for each CRUD action, slug/UUID dispatch on `Difficulty#show/update/destroy` and `DifficultyComponent#show/update`, preview happy path, missing-party preview, malformed `difficulty_rule.params` (now returns 400).

**Why not in the stack.** Adding specs to any branch in the stack rebases all branches above it. Specs aren't behavior-changing so they don't need to ship in the same PRs as the engine. One follow-up PR off `main` after the stack merges costs zero rebases.

**Files to touch (new).** `spec/requests/api/v1/difficulties_spec.rb`, `spec/requests/api/v1/difficulty_components_spec.rb`, `spec/requests/api/v1/difficulty_rules_spec.rb`, `spec/requests/api/v1/difficulty_previews_spec.rb`, `spec/requests/api/v1/difficulty_drafts_spec.rb`.

---

## Rule-class specs and calibration coverage

**Status:** deferred per the original review plan (R3 routing).

**What.** `spec/services/party_difficulty/calculator_spec.rb` covers the calculator but stubs every rule via `instance_double`. None of the 25+ rule classes has its own spec.

**What to do.** Cover `Base#decay_factor_for`, `scale_by_count` accounting, the "max_count caps denominator but not numerator" branch in `rule_contribution`, and `min_count` gating. Add regression tests for the weapon-tier exclusivity that the calibration migrations enforce (e.g. a Trans5 Dark Opus should fire `Trans5 Dark Opus weapon` but not the lower-tier `Trans3 Dark Opus weapon`).

**Why not in the stack.** Same rebase argument as above.

---

## Consolidate the difficulty seed/calibration migration chain

**Status:** deferred per the original review plan (R3 routing).

**What.** `20260510130005_seed_party_difficulty.rb` seeds rules; `20260510140000_resync_party_difficulty_rules.rb` immediately `delete_all`s and re-seeds; `20260510200000_make_weapon_tiers_exclusive.rb` deletes specific rules; downstream calibration migrations reference rules by name via `update_all`.

**What to do.** Once calibration stabilizes, consolidate into a single idempotent seed migration. Greenfield setup is fine today, but a re-run or hand-edited seed mid-chain produces the wrong set of active rules. Calibration `update_all`s also no-op silently when a rule name doesn't exist at that timestamp.

**Why not in the stack.** Consolidation requires the calibration work to be finished. Weights are still being tuned (see commits `9eea4c66`, `af64ef41`, `1c6e3217`, `7d845471` in the `-score` history).
