# No Silent Failures

Log all failures before continuing. Never silently filter None, null, empty, or error states.

**Pattern:** detect failure → log (agent, stage, error detail) → continue.

**Examples:** "Agent X returned empty output for task Y" / "File Z not found; proceeding with fallback" / "Agent X failed with exit N; task Y incomplete"

**Batch rule:** If >50% of parallel agents fail, halt and surface to user immediately.
