# Content Ideas

## "Why does etcd have two B-trees?"
The in-memory treeIndex + BoltDB B+Tree. Most people don't know both exist, let alone why. Explain the two different access patterns (revision scan for watch vs key lookup for GET) and why neither alone suffices.

## "How Raft actually commits an entry"
Not the paper-level explanation — the actual path: unstable log → WAL write → quorum acks → maybeCommit → bcastAppend (why this last broadcast?) → apply. Most content stops at "majority votes."

## "The partition scenario most tutorials skip"
Leader writes to WAL, gets isolated, comes back as follower. What happens to that entry? Log contiguity, why E+1 can't be committed without E, how the new leader overwrites stale entries. Concrete and surprising.

## "Why etcd sends MsgApp to followers before writing to its own WAL"
The leader parallelism optimization (Raft thesis §10.2.1). Most people assume WAL write must come first. The correctness argument is non-obvious.

## "What consistent_index actually is"
Idempotency under re-apply, why it's written inside the same BoltDB transaction as the state machine write, the pre-commit hook pattern. Completely invisible in the docs.

## "How etcd's watch works under the hood"
Not the API — the actual scan: BoltDB revision-ordered pages, O(log N + K) complexity, victim watchers, what happens when compaction kills your watch. k8s engineers use watch every day and have no idea how it works.

## "Go concurrency patterns etcd uses that you should steal"
nil channel gating, the pipeline pattern (rkvc), stepsOnAdvance as deferred message replay, RWMutex on a "read-only" transaction. Each is a concrete, copy-able pattern with a clear problem it solves.

## "MVCC: how etcd stores every version of every key"
Revision encoding (why big-endian matters), keyIndex generations, what a tombstone actually is, how restore() reconstructs the B-tree after crash. Directly relevant to anyone building versioned storage.

---

## Broadest reach (beyond etcd specifically)
- The partition scenario — universal Raft concept
- The two B-tree problem — universal storage design question
- Go concurrency patterns — useful for any Go developer
