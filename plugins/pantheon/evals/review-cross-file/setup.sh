#!/usr/bin/env bash
# Seeds a small shop codebase. money.js was just changed from cents to dollars;
# two of its three callers still pass cents. The diff alone looks correct.
set -euo pipefail
mkdir -p src test

cat > src/money.js <<'EOF'
// Formats an amount in dollars as a price string, e.g. formatPrice(12.5) -> "$12.50".
function formatPrice(dollars) {
  if (!Number.isFinite(dollars)) throw new TypeError(`not a number: ${dollars}`);
  return `$${dollars.toFixed(2)}`;
}

module.exports = { formatPrice };
EOF

cat > src/cart.js <<'EOF'
const { formatPrice } = require('./money');

// Items carry integer cents to avoid float rounding.
function lineTotal(item) {
  return formatPrice(item.priceCents * item.qty);
}

function cartSummary(items) {
  const totalCents = items.reduce((sum, i) => sum + i.priceCents * i.qty, 0);
  return { lines: items.map(lineTotal), total: formatPrice(totalCents) };
}

module.exports = { lineTotal, cartSummary };
EOF

cat > src/invoice.js <<'EOF'
const { formatPrice } = require('./money');

function invoiceLine(invoice) {
  return `Invoice ${invoice.id}: ${formatPrice(invoice.totalCents)} due ${invoice.dueDate}`;
}

module.exports = { invoiceLine };
EOF

cat > src/receipt.js <<'EOF'
const { formatPrice } = require('./money');

// order.totalDollars is already converted by the payments service.
function receiptFooter(order) {
  return `Paid ${formatPrice(order.totalDollars)} by ${order.method}`;
}

module.exports = { receiptFooter };
EOF

cat > test/money.test.js <<'EOF'
const { formatPrice } = require('../src/money');

test('formats dollars', () => {
  expect(formatPrice(12.5)).toBe('$12.50');
});
EOF
