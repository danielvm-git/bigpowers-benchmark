# e04s04 — Complete suite of 7 discriminating tasks
<!-- story: e04s04 -->

**type:** feature
**risk:** P0
**context:** tasks
**BCPs:** 6

## Problem
Finalize 7 discriminating benchmark tasks for rigorous A/B evaluation. The gate was re-scoped from 10 after 52 tasks showed that clean specs are solved and genuine hard edges fail deterministically at 0%, never entering the 20-80% band.

## Requirements
- Register the final 7 discriminating tasks with calibration evidence.
- Pin the gate at 7 in `benchmarks/ab/config.yaml` and list the tasks in `benchmarks/ab/DISCRIMINATING.yaml`.
