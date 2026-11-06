#!/usr/bin/env bash
# story: e58s01 e58s04
# ab-arm-bigpowers.sh — provision an A/B eval workdir the way a bigpowers user has it.
# Runs inside the workdir. $AB_BP_ROOT is the bigpowers checkout under test;
# $AB_RUNNER_ROOT is the benchmark runner checkout that owns the arm seeds.
# Copies (never symlinks): the agent must not be able to walk back into the repo,
# where the hidden tests live.
#
# Ablation options (e58s04):
#   AB_BP_SKILLS  all (default) | none | comma list of skill names
#   AB_BP_SEED    seed file (absolute, or relative to $AB_RUNNER_ROOT) | none
# scripts/ is copied only when at least one skill is.
set -euo pipefail
: "${AB_BP_ROOT:?AB_BP_ROOT must point at the bigpowers checkout}"
: "${AB_RUNNER_ROOT:?AB_RUNNER_ROOT must point at the benchmark runner checkout}"
SKILLS="${AB_BP_SKILLS:-all}"
SEED="${AB_BP_SEED:-benchmarks/ab/arms/bigpowers/CLAUDE.md}"

if [[ "$SKILLS" != "none" && ! -d "$AB_BP_ROOT/skills" ]]; then
  echo "ab-arm-bigpowers: $AB_BP_ROOT has no skills/ directory" >&2
  exit 2
fi

skill_dirs() {
  case "$SKILLS" in
    all) for d in "$AB_BP_ROOT"/skills/*/; do echo "${d%/}"; done ;;
    none) ;;
    *) for name in ${SKILLS//,/ }; do
         [[ -d "$AB_BP_ROOT/skills/$name" ]] || { echo "unknown skill: $name" >&2; exit 2; }
         echo "$AB_BP_ROOT/skills/$name"
       done ;;
  esac
}

mkdir -p specs/bugs specs/verifications
dirs="$(skill_dirs)"
if [[ -n "$dirs" ]]; then
  mkdir -p .claude/skills .agents/skills
  while IFS= read -r skill_dir; do
    name="$(basename "$skill_dir")"
    cp -R "$skill_dir" ".claude/skills/$name"
    cp -R "$skill_dir" ".agents/skills/$name"
  done <<< "$dirs"
  cp -R "$AB_BP_ROOT/scripts" scripts
fi
if [[ "$SEED" != "none" ]]; then
  seed_path="$SEED"
  [[ "$seed_path" = /* ]] || seed_path="$AB_RUNNER_ROOT/$seed_path"
  cp "$seed_path" CLAUDE.md
  cp CLAUDE.md AGENTS.md
fi
