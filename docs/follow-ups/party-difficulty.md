# Party Difficulty — Deferred Follow-Ups

Items surfaced during code review of the stacked `party-difficulty-*` PRs that were intentionally deferred. Each entry includes where the deferral was decided and what a future change should do.

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
