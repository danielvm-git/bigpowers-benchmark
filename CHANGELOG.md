## [1.3.1](https://github.com/danielvm-git/bigpowers-benchmark/compare/v1.3.0...v1.3.1) (2026-05-25)


### Bug Fixes

* **review:** address reviewer findings f1-f5 ([8372922](https://github.com/danielvm-git/bigpowers-benchmark/commit/83729227bbabe1fa4befa8bad2807968e111f99e))

# [1.3.0](https://github.com/danielvm-git/bigpowers-benchmark/compare/v1.2.0...v1.3.0) (2026-05-25)


### Features

* **5.1:** dashboard viewmodel, theme fixes, navigation state-loss fix ([#3](https://github.com/danielvm-git/bigpowers-benchmark/issues/3)) ([ce7c7fe](https://github.com/danielvm-git/bigpowers-benchmark/commit/ce7c7fe8f5950744cf38548d543ecd0da0c81cc0))

# [1.2.0](https://github.com/danielvm-git/bigpowers-benchmark/compare/v1.1.1...v1.2.0) (2026-05-25)


### Bug Fixes

* **lint:** Final build and test isolation fixes ([27ede83](https://github.com/danielvm-git/bigpowers-benchmark/commit/27ede836bb1c273a22f61095b4aa5cc03518c5de))


### Features

* **runner:** Add Host execution mode and Model Health features ([7a5d2e1](https://github.com/danielvm-git/bigpowers-benchmark/commit/7a5d2e127382dde135bd4d68121b8730d28f9075))

## [1.1.1](https://github.com/danielvm-git/bigpowers-benchmark/compare/v1.1.0...v1.1.1) (2026-05-24)


### Bug Fixes

* sandbox path resolution tries both benchmark and benchmark-old directories ([7a5f7a2](https://github.com/danielvm-git/bigpowers-benchmark/commit/7a5f7a2433ad6d93f10769a5cf652f895c66d747))

# [1.1.0](https://github.com/danielvm-git/bigpowers-benchmark/compare/v1.0.0...v1.1.0) (2026-05-24)


### Features

* **observability:** wire solo-dev ndjson logging and debug workflow ([0bbb093](https://github.com/danielvm-git/bigpowers-benchmark/commit/0bbb0937cc7d23a114eaa5e74bad795e6ce39f87))
* story 0.1 / 0.2 / 1.1 — foundation, theme system, app shell ([69e8d77](https://github.com/danielvm-git/bigpowers-benchmark/commit/69e8d77536550b6401078ea76323efb28b0680d5))
* **theme:** implement thememanager with persistence and auto-resolution ([123f1ab](https://github.com/danielvm-git/bigpowers-benchmark/commit/123f1ab544e74c3e6527af64756aebafd3e76d61))

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
