# ADR: Architecture, Stack, Storage, and Security Baseline

## Status
Accepted (Retroactive) — 2026-11-06

## Context
BigPowers-Benchmark requires high performance, local desktop fluidity, robust process isolation, and leak-free credential handling.

## Decisions

### 1. Stack: Swift 6 + SwiftUI on macOS 14+
- **Decision**: Native Swift macOS application using SwiftUI.
- **Rationale**: Direct integration with system APIs, instant responsiveness, native look-and-feel matching prototypes, and type-safe concurrency.

### 2. Data Store: Append-only JSON Shards & Pinned Reports
- **Decision**: JSON shards written to `~/runs/data/` for app telemetry and YAML reports in `benchmarks/reports/` for A/B evaluations.
- **Rationale**: No heavy database dependency; simple git tracking, easy inspection, and tamper-evident recording.

### 3. Authentication & Secrets: macOS Keychain
- **Decision**: Model provider API keys reside strictly in macOS Keychain via `Security.framework`.
- **Rationale**: Zero disk leaks, immune to git accidents, compliant with CONVENTIONS.md §5.

### 4. Hosting & Distribution: Local CLI & App Bundle
- **Decision**: Distributed as a signed macOS Universal App and developer CLI runner.
- **Rationale**: Benchmarks execute locally with access to Docker and host virtualization without cloud dependency.
