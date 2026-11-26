---
description: A multi-step feature request where the user asks for a plan only. Pantheon should plan (athena / orchestration) and not claim to have built anything.
tags: [plan]
max_turns: 15
timeout_seconds: 600
---

I want to add per-API-key rate limiting to our Express API. It runs as 4 instances behind a load balancer, and we already use Redis for sessions. Limits should differ by plan: free gets 60 requests a minute, pro gets 600. Clients should get a clear error when they hit the limit.

Don't write any code yet. Give me a plan I can review: the design, the order of the work, and how we'll know each step works.
