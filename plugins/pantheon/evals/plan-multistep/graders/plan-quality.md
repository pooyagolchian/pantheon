---
type: llm
weight: 1
---

The response is a plan, not an implementation. It passes when all of these hold:

- The limit state is shared across the 4 instances (for example in Redis), not kept in process memory, and it says why.
- The limit is looked up per API key from the key's plan (free 60/min, pro 600/min).
- Clients that hit the limit get HTTP 429 with a `Retry-After` header (or equivalent rate-limit headers).
- The work is broken into ordered steps, and each step says how it will be verified (a test or check).
- It does not claim to have written, run or changed any code.
