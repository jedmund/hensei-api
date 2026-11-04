# Difficulty calibration: v2

Scored 5 parties on 2026-11-04T12:00:00Z.

## Scores

| p10 | p25 | p50 | p75 | p90 | p95 | p99 | max |
|---|---|---|---|---|---|---|---|
| 12.25 | 40.0 | 55.0 | 82.5 | 100.0 | 100.0 | 100.0 | 100.0 |

| Range | Parties | Share |
|---|---|---|
| 0–10 | 0 | 0.0% |
| 10–20 | 1 | 20.0% |
| 20–30 | 0 | 0.0% |
| 30–40 | 0 | 0.0% |
| 40–50 | 1 | 20.0% |
| 50–60 | 1 | 20.0% |
| 60–70 | 0 | 0.0% |
| 70–80 | 0 | 0.0% |
| 80–90 | 1 | 20.0% |
| 90–100 | 1 | 20.0% |

## Tiers

| Tier | Range | Parties | Share |
|---|---|---|---|
| Casual | 0.0–49.99 | 2 | 40.0% |
| Endgame | 50.0–100.0 | 3 | 60.0% |

## Components

Points are the component's summed rule contributions before dividing by the denominator (`target_max`, or the sum of every rule's maximum when unset).

| Component | Weight | target_max | Denominator | Present | Fired | Points p50 | p90 | p99 | max | Raw p50 | Raw p99 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| weapon | 3.0 | 10.0 | 10.0 | 80.0% | 60.0% | 6.0 | 8.0 | 8.0 | 8.0 | 0.6 | 0.8 |
| summon | 1.5 | — | 2.0 | 20.0% | 20.0% | 1.0 | 1.0 | 1.0 | 1.0 | 0.5 | 0.5 |

## Rules

| Component | Rule | Weight | Parties fired | Share | Avg points when fired |
|---|---|---|---|---|---|
| summon | Summons | 2.0 | 1 | 20.0% | 1.0 |
| weapon | Opus | 6.0 | 2 | 40.0% | 4.0 |
| weapon | Grands | 4.0 | 2 | 40.0% | 5.0 |

## Movement against the baseline

2 of 4 parties (50.0%) changed tier (compared by slug, so renaming a tier is not a change). Rows are baseline tiers, columns are candidate tiers.

| From \ to | Casual | Endgame |
|---|---|---|
| Endgame | 1 | 1 |
| Top | 0 | 1 |
| — | 1 | 0 |

### Largest score changes

| Party | Name | Baseline | Candidate |
|---|---|---|---|
| S1 | Party 1 | 60.0 (Endgame) | 82.5 (Endgame) |
| S2 | Pipe / name | 55.0 (Endgame) | 40.0 (Casual) |
| S4 | Party 4 | 90.0 (Top) | 100.0 (Endgame) |
| S3 | Party 3 | 12.25 () | 12.25 (Casual) |
