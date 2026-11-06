# External task sources

Criteria for this benchmark:

- 200–1,500 LOC fixture, or a spec that can be implemented in that range.
- Node or Python only unless the agent image is extended.
- Specs with observable contracts, not step-by-step implementation recipes.
- Hidden tests we write ourselves, even when the source ships tests.
- License allows adaptation. A public benchmark can still be contaminated; prefer
  private/rotated tasks or write fresh fixtures from the spec.

## Shortlist

| Source | License | Size / language | What it gives us | Fit |
|---|---|---|---|---|
| [`eswat2/proto-specs`](https://github.com/eswat2/proto-specs) | **MIT** | two small web apps, spec-only | Cleanroom `SPEC.md` + acceptance checklist. Planning poker and retro board. | **Best spec-only source.** Adapt the backend subset into a Node API task. |
| [`intent-bench/intent-bench`](https://github.com/intent-bench/intent-bench) | **Apache-2.0** | url-shortener (10 reqs), task-manager (13 reqs) | Structured intent artifacts, A/B methodology, greenfield tasks. | **Best small/mid greenfield source.** |
| [`WecoAI/SpecBench`](https://github.com/WecoAI/SpecBench) | **Apache-2.0** | 30 tasks, 1.5K–110K LOC, Python/C/Go | Specs, stubs, reference solutions, visible + held-out suites, reward-hacking framing. | **Best hidden-test design source.** Use the smaller Python tasks (json_parser, package_resolver, http_server, regex_engine). |
| [`specdd/example`](https://github.com/specdd/example) | **Apache-2.0** | tiny JS todo app | Colocated `.sdd` specs, spec-driven example. | Good warm-up/control task, not discriminating on its own. |
| [`codecrafters-io/ccbench`](https://github.com/codecrafters-io/ccbench) | **no license** | 187 tasks, <10k LOC | Real CodeCrafters user code, not in training data, Harbor format. | **Best contamination profile, but do not copy.** Use as inspiration/format only; ask permission before reuse. |
| [`Gradient-Data/Zero2Repo`](https://github.com/Gradient-Data/Zero2Repo) | **no license** | 17 cases, small/mid | Spec + empty workspace + hidden acceptance tests. | Good shape reference; do not copy. |
| [`EnvCommons/NL2RepoBench`](https://github.com/EnvCommons/NL2RepoBench) | **no license** | 103 Python repos, long specs | Natural-language repo specs, pytest reward. | Inspiration only; no license to reuse. |
| [`dhruvpatel1706/swe-agent-lite`](https://github.com/dhruvpatel1706/swe-agent-lite) | **no license** | 13 tiny bug fixes | Failure-mode tags, small bug tasks. | Inspiration only; not spec-driven. |
| [`LiveCodeBench`](https://github.com/LiveCodeBench/LiveCodeBench) | permissive (check) | competitive programming | Contamination-free over time | Different shape; not repo/spec tasks. |
| [`Multi-SWE-bench mini`](https://huggingface.co/datasets/ByteDance-Seed/Multi-SWE-bench_mini) | CC0 + upstream licenses | 400 instances | Real PR/issue tasks | Heavy; contamination risk on popular repos. |

## Recommended next three tasks

### 1. `ab-24` — URL shortener (intent-bench, Apache-2.0)

Small greenfield Node HTTP API, ~300–500 LOC:

- create link, custom alias, collision, expiry, redirect, click count, idempotency.
- Hidden tests: alias validation, collision, expiry boundary, unknown code, analytics,
  malformed JSON, regression.

Why: small enough to finish, enough requirements to show planning and edge-case discipline.

### 2. `ab-25` — Planning poker backend (proto-specs, MIT)

Adapt the backend subset of `poker/SPEC.md` into an in-memory Node API:

- create/join/vote/reveal/new-round/topic, exact status codes and error shape;
- no-op vote vs accepted vote, unknown participant, room expiry;
- concurrency: 25 simultaneous joins/votes with no lost updates;
- hidden tests from the spec's acceptance checklist.

Why: the spec is genuinely implementation-derivable and has a ready acceptance checklist.
Do not include the frontend/SSE/Redis parts in the first adaptation; keep it to the state
machine and concurrency rules.

### 3. `ab-26` — JSON parser (SpecBench, Apache-2.0)

Python or Node parser, ~500–800 LOC:

- strings/escapes/unicode, numbers, arrays/objects, nesting, duplicate keys, errors;
- hidden tests: valid/invalid corpus, boundaries, deep nesting, error positions;
- reference solution and held-out tests exist upstream; use them as design input, write
  our own fixtures and tests.

Why: a classic long-horizon task with a precise observable contract and many edge cases.

## Adaptation rules

1. **Never copy upstream hidden tests.** Even Apache-2.0 tests may encode the reference
   implementation and may be in training data. Write our own from the spec.
2. **Keep attribution.** For MIT/Apache-2.0 sources, record the repo URL, license, and commit
   in `task.yaml` (`source:` block) and in `benchmarks/docs/`.
3. **No-license sources are inspiration only.** Do not copy spec text, code, or tests.
4. **Prefer specs, not implementations.** A spec-only source (proto-specs) is better than a
   repo with a reference solution because it reduces leakage.
5. **Keep the runtime closed.** Node/Python only; no new services (Redis, Postgres, Bun) unless
   the agent image is deliberately extended.
6. **Calibrate vanilla before adopting.** A task that vanilla solves 10/10 is a control, not a
   benchmark. Aim for 20–80%.

## Do not use (yet)

- SWE-bench Verified / popular OSS issue tasks: heavy setup and training-data contamination.
- CCBench / Zero2Repo / NL2RepoBench content without written permission: no license.
- 10K+ LOC systems tasks: our agent timeout and harness are not built for them yet.
