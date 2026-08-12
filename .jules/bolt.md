## Caching Storage Reads

**Observation:** When a mapping entry or a struct from storage is accessed multiple times within a function (e.g., checking multiple fields of a struct), each access incurs an `SLOAD` cost if the compiler doesn't optimize it, or at least redundant mapping key hashing and storage pointer calculations.

**Optimization:** We can cache the struct pointer in memory by declaring it as a `storage` variable (e.g., `User storage user = users[msg.sender];` or `Bounty storage bounty = bounties[bountyId];`). This reduces gas cost and makes the code slightly more readable.

**Measurement:** In `submitBid`, replacing multiple accesses of `users[msg.sender]` and `bounties[bountyId]` with `storage` pointers reduced the function's gas cost from `81880` to `81654`, saving about `226` gas.
