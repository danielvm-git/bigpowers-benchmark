# Issue #42: due dates for the todo CLI

## Comment 1 — maintainer

Please let a todo carry an optional due date, and add `todo list --overdue --today YYYY-MM-DD`
so I can see what is late. `--today` is required for an overdue list so the result is
deterministic; a missing or malformed value fails with `invalid today: <value>`.
A todo without a due date is never overdue. A completed todo is never overdue either, even
when its due date is in the past.

## Comment 2 — product

Use ISO-8601 dates (`YYYY-MM-DD`) everywhere, including the stored file and JSON output. Add a
`--json` mode to `todo list` so scripts can consume it. In JSON, a missing due date must be
`null`, not an empty string. An invalid due date fails with `invalid due date: <value>`.

## Comment 3 — maintainer

My existing `todos.json` files predate this change and have no due field. They must keep
loading, and the items must not be lost. After loading, a missing due date behaves as `null`.
