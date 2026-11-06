# Specification: collaborative todo lists

## API

- `createUser({ id, name })`
- `createList({ id, ownerId, name })`
- `shareList({ listId, ownerId, userId })`
- `createTask({ id, listId, userId, title })`
- `completeTask({ taskId, userId })`
- `listTasks({ listId, userId })`
- `transferOwnership({ listId, ownerId, newOwnerId })`
- `reset()`

## Rules

1. **Lists.** Unique id; owner must exist. A member is the owner or a shared user.
2. **Share.** Only the owner can share (`not_list_owner`); the target user must exist; sharing
   with the owner or an existing member is a no-op.
3. **Tasks.** Only a member can create, complete or list tasks (`not_list_member`). Task ids are
   unique; title is non-empty. `completeTask` is idempotent; unknown task is
   `task_not_found: <id>`. `listTasks` preserves creation order.
4. **Ownership transfer.** Only the owner can transfer (`not_list_owner`); the new owner must be a
   member (`not_list_member`). The old owner stays a member; the new owner becomes the owner.
5. **Unknown ids.** `user_not_found: <id>`, `list_not_found: <id>`.

## Invariants

- Existing tests in `test/todo.test.js` keep passing.
- A non-member never sees or mutates a task.
