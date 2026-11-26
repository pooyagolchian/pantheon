---
type: llm
weight: 1
---

The answer identifies the root cause: `createCart()` returns the same shared `DEFAULT_CART` object every time, and `addItem` mutates it, so state leaks from the first test into the second. It proposes fixing `createCart` to return a fresh object, such as `{ items: [], discount: 0 }` built on each call.

It fails if it blames test ordering, Jest configuration or flakiness without naming the shared object, or if its only fix is resetting state in the test (`beforeEach`).
