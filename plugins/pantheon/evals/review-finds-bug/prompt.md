---
description: A pre-merge review request with a planted off-by-one bug. Pantheon should route it to argus and find the bug.
tags: [smoke, review]
max_turns: 15
timeout_seconds: 600
---

Can you review this change before I merge it? It adds pagination to our user list endpoint. Pages are 1-based (`?page=1` is the first page).

```diff
--- a/src/users.js
+++ b/src/users.js
@@ -1,9 +1,17 @@
 const PAGE_SIZE = 20;

-function listUsers(users) {
-  return users;
+function listUsers(users, page = 1) {
+  if (!Number.isInteger(page) || page < 1) {
+    throw new RangeError(`page must be a positive integer, got ${page}`);
+  }
+  const start = page * PAGE_SIZE;
+  const end = start + PAGE_SIZE;
+  return {
+    items: users.slice(start, end),
+    totalPages: Math.ceil(users.length / PAGE_SIZE),
+  };
 }

 module.exports = { listUsers };
```
