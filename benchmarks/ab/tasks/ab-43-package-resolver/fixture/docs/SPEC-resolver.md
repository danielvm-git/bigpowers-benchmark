# Specification: package resolver

## API

`resolve({ root, registry })` where `registry` maps a package name to an array of
`{ version, dependencies }` and `dependencies` maps a name to a range.

Returns `{ selected: {name: version}, order: [name] }`; `order` is dependency-first and contains
each selected package once.

## Versions and ranges

Versions are `major.minor.patch` numbers. Ranges:

- `*` — any version;
- exact `1.2.3`;
- `^1.2.3` — `>=1.2.3` with the same major;
- `~1.2.3` — `>=1.2.3` with the same major and minor.

Choose the highest version satisfying every constraint on that package. If no version satisfies
all constraints, fail with `version_conflict: <name>`. An unknown package fails with
`package_not_found: <name>`. Every version in the registry must be `major.minor.patch`; an invalid
version anywhere fails with `invalid_version: <version>`.

## Invariants

- Existing tests in `test/resolver.test.js` keep passing.
- Cycles resolve to one version per package and terminate.
