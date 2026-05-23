# 1.0.0 (2026-05-23)


### Bug Fixes

* activate nsapp on launch so window appears when run via swift run ([54fb925](https://github.com/danielvm-git/bigpowers-benchmark/commit/54fb925d8a12a9d106ff45e3487a7bd30c3226ac))
* **audit:** rename decoder container, clean git api, add process timeouts, fix watch race ([ddb3fb7](https://github.com/danielvm-git/bigpowers-benchmark/commit/ddb3fb797ebf7780d8fe9f911956d4c44498c4c4))
* defer nsapp activation to applicationdidfinishlaunching via delegate adaptor ([cc5528d](https://github.com/danielvm-git/bigpowers-benchmark/commit/cc5528dc8aa49e76ad24770549e69f07195881f7))
* **git-service:** strip git hook env vars from spawned git subprocesses ([70579a5](https://github.com/danielvm-git/bigpowers-benchmark/commit/70579a5cf59871b707aa9e61f22a0cbbf8f58a3b))
* **review:** address all must-fix and should-fix findings from code review ([ead3f3a](https://github.com/danielvm-git/bigpowers-benchmark/commit/ead3f3af22f6460e91ae38a778c74eb9e5dabf27))
* simplify contentview and exclude entitlements from package sources ([cd9c7f4](https://github.com/danielvm-git/bigpowers-benchmark/commit/cd9c7f4bca5d095fc16b6c6d2da00548410d5e46))
* simplify contentview to resolve attributegraph cycle on launch ([1b00576](https://github.com/danielvm-git/bigpowers-benchmark/commit/1b00576295a863d262e572631a2a13b11d998272))


### Features

* **benchrow:** add benchrow model with snake_case json coding and computed overall score ([2e330e2](https://github.com/danielvm-git/bigpowers-benchmark/commit/2e330e2f9ff07b882adc34492a9a5d3817940956))
* **foundation:** add package.swift and app entry point stub ([47b7944](https://github.com/danielvm-git/bigpowers-benchmark/commit/47b794483bcabefdae3573cba0429b94a6348d7e))
* **shell:** add navigationsplitview shell with toolbar, menubarextra, and onboarding sheet ([bcdda0f](https://github.com/danielvm-git/bigpowers-benchmark/commit/bcdda0f3aa6a085b3da91d85087ed983712fe006))
* **shell:** add screen enum with 8 navigation cases and entitlements stub ([91c43e7](https://github.com/danielvm-git/bigpowers-benchmark/commit/91c43e75a488e148b25f4f6dd9ab979111033ebd))
* **store:** add benchmarkstore, gitservice, and runprogress with full tdd coverage ([50ab2b3](https://github.com/danielvm-git/bigpowers-benchmark/commit/50ab2b399a3e3454068b2ec674d28c59816f2c69))
* **theme:** add theme enum, 13-theme token tables, and thememanager with userdefaults persistence ([a91549a](https://github.com/danielvm-git/bigpowers-benchmark/commit/a91549a6be4a56426d4aaf505cc7e422b2d46906))
