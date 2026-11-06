# e04s02 — calibration evidence

Date: 2026-11-04
Adapter: `pi-docker`
Model: `opencode-go/deepseek-v4.1-flash`
Subject: `/Users/danielvm/Developer/bigpowers` @ `52842a2f` (clean)
Runner: `bigpowers-benchmark` @ `1d4978f` (dirty, recorded)
Reports:

- `benchmarks/reports/CALIBRATION-2026-11-04-full.yaml` — before the ambiguity fix, k=10
- `benchmarks/reports/CALIBRATION-2026-11-04-retest.yaml` — after the ambiguity fix, k=5

## Before the fix (k=10)

| Task | Passes / runs | Pass rate | Mean score | Band | Notes |
|---|---:|---:|---:|---|---|
| ab-09 | 8 / 10 | 0.80 | 0.9833 | discriminating | upper boundary |
| ab-17 | 0 / 10 | 0.00 | 0.9231 | too_hard | 1 agent error; 12/13 hidden tests passed in run 1 |
| ab-19 | 10 / 10 | 1.00 | 1.0000 | too_easy | — |
| ab-20 | 0 / 10 | 0.00 | 0.3077 | too_hard | brand mismatch in every run |

The 0/10 results were **spec ambiguities**, not difficulty:

- `ab-17`: the hidden test asked what `listAliases` does for an unknown account. The solution
  returned `[]`; the agent called `getAccount` and threw. The spec now states the empty-list
  behaviour.
- `ab-20`: the codes targeted `acme` / `zenith`, but the spec never said the brand strings were
  lowercase. The agent used `"Acme"` / `"Zenith"`. The spec now names the lowercase values
  explicitly.

## After the fix (k=5 retest)

| Task | Passes / runs | Pass rate | Mean score | Band |
|---|---:|---:|---:|---|
| ab-17 | 5 / 5 | 1.00 | 1.0000 | too_easy |
| ab-20 | 5 / 5 | 1.00 | 1.0000 | too_easy |

Both tasks moved from `too_hard` to `too_easy`. The ambiguity fix was correct, but it did not
put them in the 20–80% band.

## Conclusion

After the de-prescription and hidden-test work, the four hard tasks are:

| Task | Band |
|---|---|
| ab-09 | discriminating, at the 0.80 upper boundary |
| ab-17 | too_easy |
| ab-19 | too_easy |
| ab-20 | too_easy |

For this model, the suite still does not discriminate. The next lever is length and state, not
more hidden tests: multi-step / multi-session tasks and larger codebases (e04s03). A full k=10
confirmation of ab-17/ab-20 is recommended before retiring them.

## Reproduction

```bash
# full, before the fix (preserved)
cat benchmarks/reports/CALIBRATION-2026-11-04-full.yaml

# post-fix retest
bash scripts/ab-calibrate.sh --tasks ab-17,ab-20 --k 5 --no-calibration-cache \
  --bigpowers-root /Users/danielvm/Developer/bigpowers
```
