# Questions — Checkpoint 5 (2026-08-19)

_Extracted from conversation since: 2026-08-09_

---

## Raft Log Storage — MemoryStorage.Append (Conflict Truncation)

- explain the use case of this:
  ```go
  ms.ents = append(ms.ents[:offset:offset], entries...)
  src: ~/go/pkg/mod/go.etcd.io/raft/v3@v3.7.0-rc.1/storage.go#L318
  ```
- why would it clobber memory?
- so, the case that @~/go/pkg/mod/go.etcd.io/raft/v3@v3.7.0-rc.1/storage.go#L318-318 solves is 'conflict truncation'?
- is the index guaranteed to be monotonically increasing?
  ```go
  offset := entries[0].GetIndex() - ms.ents[0].GetIndex()
  src: ~/go/pkg/mod/go.etcd.io/raft/v3@v3.7.0-rc.1/storage.go#L313
  ```
- if not monotinically increasing, at least are Index values consecutives?
- provide a simple example of where entries would need to be discarded. here is what I am thinking of:
  ```
  1. 3-node cluster: A, B, C; A = leader;
  2. index = 5; all in sync;
  3. a sends 3 new entries to B; entries are replicated (e.g. saved in memory storage); resulting index = 8
  4. A is partitioned;
  5. A rejoins;
  6. C is leader;
  7. C sends one entry (so, index = 6) to both A and B;
  8. on A: len(entrs) = 8 > offset (6 - 0 = 6) -> entries 7 and 8 need to be discarded. -> A.ents = A.ents[:6:6]
  ```
  am I correct with this example? help me arrive to a simple and insightful example;

  additional questions:
  1. at point 4, the cluster cannot nor reads not writes, right? basically, it stops making progress.
  2. in which cases would A's 8-length entries be used by other goroutines?
- re 1: after A being partitoned, does it not mean that B and C will end up with a split-vote since each will vote for itself?
- re example: yes, but A, as a leader, will first write to rd.Entries to WAL and then to in-memory storage @etcd/server/etcdserver/raft.go#L256-287. can WAL entries be discarded? I don't think so.

---

## Debugging Techniques — Process Signals

- why is sigstop & sigcontinue time-sensitive to changes?

---

## Concurrency & Synchronization — MemoryStorage Locking

- @~/go/pkg/mod/go.etcd.io/raft/v3@v3.7.0-rc.1/storage.go#L313-317
  how does it know that Entries() might be referenced from outside?
  how does it know that Entries() can be called from multiple goroutines?
- why mutex and not RWmutex?
- writer-starvation-avoidance -- elaborate on this. where can i readmore about it?
- but in app's goroutine, there can be multiple concurrent invocations of that loop goroutine (i.e. multiple PUT requests coming sequently), so technically there could be concurrent reads. or am I wrong?
- that single processing goroutine reading, versus the application's separate Append() call after persisting to WAL -- so the app's goroutine, which calls Append(), is the 'single consumer' ?
- ok, and being only 2 -- one reader and one writer -- it does not make sense to have more than sync.Mutex. correct?

---

## Terminology

- 'exact same idiom as' -- what is 'idiom'?

---

## Storage Semantics — Entries() Staleness

- from ealier: i understand that Entries() called before Append() could result in some stale state?
- what do you mean by 'logical staleness'?

---

## etcd Performance & Operations

- what is the typical traffic expected for etcd? what is typical number of concurrent requests for etcd?
- where are etcd's benchmarks avaialble at?
- what do you mean by keyspace?
- what do you mean by 'large number of Pods churning'?
- is etcd more read-heavy than write-heavy?
- ok, but why capping the keyspace at 2GB? the larger, the more BoltDB's B+Tree traversals and the higher the costs of fsync on a single 2GB file? i understand that 'keyspace of 2gb' = 'the BoltDB's single database file is 2gb in size'. does compaction (e.g. snapshots) help with this?
- 'low turnover' -- what is it?
- ok, so etcd is read-heavy and write-bound. what are the 2 traits generically called? 'boundness'? or what?
- 'out-of-band' meaning in the context of defragmentation?
