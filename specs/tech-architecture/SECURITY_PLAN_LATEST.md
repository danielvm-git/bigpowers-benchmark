# Security Plan & Threat Model

## Threat Model (STRIDE)

| Threat Category | Potential Vector | Mitigation & Controls |
|---|---|---|
| **Spoofing** | Unauthorized access to model provider APIs | Credentials stored only in macOS Keychain (`SecItemAdd`), never in files or process environment. |
| **Tampering** | Agent modifying protected test suites during benchmark run | Worktrees are isolated and hashed; tamper detection flags any edit or deletion in protected test files. |
| **Repudiation** | Mutated task or test definitions post-run | All runs record input SHA provenance, dirty status, and frozen task tree hashes. |
| **Information Disclosure** | Leakage of API tokens in log streams or UI | `ShellCommandRunner` and `Logging` redact sensitive patterns; `.env*` files are strictly gitignored. |
| **Denial of Service** | Unbounded external process execution / infinite loops | Strict timeouts on all process launches (`timeoutMs`); container resource caps in Docker runner. |
| **Elevation of Privilege** | Arbitrary code execution on host from untrusted model output | Benchmarks execute inside ephemeral Docker containers (`pi-docker`) with dropped capabilities. |
