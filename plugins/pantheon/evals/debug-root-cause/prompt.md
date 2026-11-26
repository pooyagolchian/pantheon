---
description: A flaky-looking test failure whose root cause is shared mutable state. The answer should name the cause, not just patch the symptom.
tags: [smoke, debug]
max_turns: 15
timeout_seconds: 600
---

This test passes when I run it alone but fails when I run the whole file. Why? I don't want a workaround, I want to know what's actually wrong.

```js
// cart.js
const DEFAULT_CART = { items: [], discount: 0 };

function createCart() {
  return DEFAULT_CART;
}

function addItem(cart, item) {
  cart.items.push(item);
  return cart;
}

module.exports = { createCart, addItem };
```

```js
// cart.test.js
const { createCart, addItem } = require('./cart');

test('adds an item', () => {
  const cart = addItem(createCart(), { sku: 'A1', price: 5 });
  expect(cart.items).toHaveLength(1);
});

test('new cart is empty', () => {
  expect(createCart().items).toHaveLength(0);
});
```

```
FAIL  ./cart.test.js
  ✕ new cart is empty
    expect(received).toHaveLength(expected)
    Expected length: 0
    Received length: 1
```
