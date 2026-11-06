# Specification: social feed visibility

## Overview

An in-memory follow graph and feed. Public posts are visible to everyone; followers-only posts
need an accepted follow; a private account exposes its posts only to accepted followers and itself.
The feed is newest-first with cursor pagination.

## API

- `createUser({ id, private = false })`
- `follow({ followerId, followeeId })`
- `acceptFollow({ followerId, followeeId })`
- `rejectFollow({ followerId, followeeId })`
- `createPost({ id, userId, text, visibility = "public" })`
- `feed({ userId, limit = 10, cursor = null })`
- `canView({ viewerId, postId })`
- `reset()`

## Rules

1. **Users.** Unique non-empty id; `private` is a boolean. Duplicate id fails with
   `duplicate_user: <id>`.
2. **Follow.** No self-follow (`self_follow`); both users must exist. A duplicate request is a
   no-op. Following a private account returns `{ status: "pending" }`; following a public account
   returns `{ status: "accepted" }`.
3. **Accept/reject.** Only a pending request can be accepted or rejected; otherwise
   `follow_not_found`. Accepting makes the follow effective; rejecting removes it.
4. **Posts.** Unique id, existing user, non-empty text, `visibility` is `public` or `followers`.
   Invalid visibility fails with `invalid_visibility`; duplicate id with `duplicate_post: <id>`.
5. **Visibility.** The author always sees their own post. A post from a private account is visible
   only to accepted followers and the author. Otherwise `public` posts are visible to everyone and
   `followers` posts only to accepted followers.
6. **Feed.** Newest first by `seq` descending; `cursor` is the last `seq` from the previous page and
   returns only `seq < cursor`. `limit` is a positive integer (default 10).
7. **Lookup.** Unknown users/posts fail with `user_not_found: <id>` / `post_not_found: <id>`.

## Invariants

- Existing tests in `test/social.test.js` keep passing.
- A pending follow never grants visibility.
