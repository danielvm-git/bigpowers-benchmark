# e02s01 — Pin clean checkout and content hashes in report metadata
<!-- story: e02s01 -->

**type:** feat
**risk:** P0
**context:** infra
**BCPs:** 5

## Context

A benchmark number is only meaningful if you know exactly what ran. Today the report records
`bigpowers_sha`, but not dirty status, task-tree content, config content or the Docker image. This
story adds an `inputs` block to every report and aborts a dirty subject unless the operator opts in.

Required inputs:

```yaml
inputs:
  schema: 1
  subject:
    path: /path/to/bigpowers
    sha: 40-hex
    ref: HEAD
    dirty: false
    dirty_diff_sha: null
  runner:
    root: /path/to/bigpowers-benchmark
    sha: 40-hex
  config:
    path: benchmarks/ab/config.yaml
    sha256: 64-hex
  image:
    name: bp-ab-agent:pi-1.5.0
    id: sha256:...
  tasks:
    ab-11:
      task_yaml: 64-hex
      fixture: 64-hex
      hidden: 64-hex
      audit: null
      solution: 64-hex
```

## Steps

1. Add `scripts/lib/ab_provenance.py`: `sha256_file`, `sha256_tree`, `git_state`, `docker_image_id`, `collect_inputs` → verify: `python3 -m py_compile scripts/lib/ab_provenance.py`.
2. `sha256_tree` sorts relative paths and hashes `relpath\0content\0`; exclude `.git`, `node_modules`, `vendor`, `__pycache__`, `.DS_Store` → verify: `python3 Tests/test_ab_provenance.py`.
3. Add `--allow-dirty` (default false) and call `collect_inputs` before round 1; exit 2 if `dirty` and not allowed → verify: `python3 Tests/test_ab_provenance.py`.
4. Write `inputs` into the report meta and `input_digest` into every JSONL record → verify: `python3 Tests/test_ab_eval.py`.
5. Add `--verify-inputs <report>` that recomputes and diffs, exiting 2 on mismatch → verify: `python3 Tests/test_ab_provenance.py`.
6. Document the block in `benchmarks/docs/SCHEMA-AB.md` → verify: `rg -n 'inputs:|dirty_diff_sha|image:' benchmarks/docs/SCHEMA-AB.md`.

## Verification Script (Step-by-Step)

1. Make the subject dirty; run a dry run; confirm exit 2 and the offending paths.
2. Re-run with `--allow-dirty`; confirm the report records `dirty: true` and a diff hash.
3. Edit one hidden test; run `--verify-inputs`; confirm exit 2.
4. Tag a new image; confirm the report records the new image ID.

## Out of scope

- Signing reports.
- Hashing the agent's own output (that is the patch hash, e06).

## Risks

- Hashing `node_modules` would be slow and noisy; exclude vendor dirs explicitly.
- A dirty tree copied with `rsync` may include untracked secrets; the allow-dirty path must warn loudly.
- Docker may be unavailable for host adapters; record `null` and a warning, not a crash.

## Acceptance Criteria

- [ ] Every report has a complete `inputs` block.
- [ ] A dirty subject aborts by default.
- [ ] `--verify-inputs` detects any drift.
- [ ] The image digest is recorded when Docker is in use.
