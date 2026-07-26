# Questions — Checkpoint 3 (2026-07-24)

_Extracted from conversation since: 2026-07-17_

---

## BoltDB Internals

- why does setting a chunk size amortize the read impact? is it about disk I/O?
- are boltdb's leaves stored by revision key?
- what is the complexity of a watch loop's scan? O(logN) + O(K), where logN is the B+tree height and K is the number of values (revisions) in boltDB?
- btw, are boltdb's values linked between eachother?
- during boltdb compaction, will old revisions be deleted actually?
- what do you mean by 'amortized O(1) per entry'? which entry? why O(1)?

## MVCC & B-tree

- I still don't understand why it is amortised. Maybe I don't understand what the construction entails?
- also, is the 'revision' number ever reset?
- if there are many revisions, there will be a much leaf nodes -- correct? (in a b+tree).
- in order to construct the user-key-based b-tree, we need to start from the first leaf. is it not always (first_revision, 0)?
- btw, is pipelining a proper term for such scenario? e.g. when read and construction can happen in parallel?
- so, after mvcc compaction, when reconstructing the b-tree, you can no longer start from (1, 0) revision. correct? I guess that's part of the challenge, i.e. to find the first leaf?
- why is the data model in boltdb made of {revision: actions}, the one -- the in-memory b-tree -- in mvcc made of { resource_path: { revision } }? what problems are solved by this?
- does etcd need to account for some specific way that K8s works under the hood?
- why not solely rely on boltdb?
- mvcc basically relies on boltdb. however, mvcc's in-memory b-tree is built on the state that's in boltdb. i understand that a b-tree is used because you get the best of both array (range queries, but slow inserts) and a hashmap (fast insertion, but no order guaranteed). is this correct?
- what is an 'audit log'?

## etcd Watch

- what is etcd's watch? is this the watchstore? what does it do?
- O(total revisions), which grows unboundedly -- is this far-fetched, because there is boltdb compaction, right?
- if so, what happens with existing controllers which have their watches ongoing?
- can a controller take as long as 5 minutes to catch up? sounds a lot.

## Compaction & Snapshots

- so, compaction & snapshot do not actually concern boltdb -- only WAL, correct?

## Raft Protocol

- is what's going on in acceptReady() -- `/Users/andrei/go/pkg/mod/go.etcd.io/raft/v3@v3.7.0-rc.1/rawnode.go` -- a sort of optimistic update? i.e. in this function, it is prepared what to do on the next 'advance' event.
- when can applyingEntsSize overflow?
  ```go
  l.applyingEntsPaused = l.applyingEntsSize >= l.maxApplyingEntsSize
  ```
- why 'saturating' it to 0 reduces chances of overflow?
  ```go
  func (r *raft) reduceUncommittedSize(s entryPayloadSize) {
      if s > r.uncommittedSize {
          r.uncommittedSize = 0
      } else {
          r.uncommittedSize -= s
      }
  }
  ```
- the difference between these two is that MsgStorageAppendResp concerns commitedEntries (i.e. logs saved to WAL); and MsgStorageApplyResp concerns applied entries? in raft, IIRC, committed index tracks logs that are persisted to the machine, but appliedIndex tracks the logs that have actually been applied to the state machine. BTW, the distinction between applied and commit index exists because they are not atomic operations in practice. moreover, they are async actions which in reality means a lot of things can go wrong from 'replication' to 'applying'. additionally, the raft node needs to be responsive in the network, so it does afford to perform both commit & apply in the same go. (there is the log index, which tracks the logs that have been added to in-memory storage -- correct?) help me properly understand this logic behind raft.
  ```go
  case pb.MsgStorageAppendResp:
      if m.GetIndex() != 0 {
          r.raftLog.stableTo(entryID{term: m.GetLogTerm(), index: m.GetIndex()})
      }
      if m.GetSnapshot() != nil {
          r.appliedSnap(m.GetSnapshot())
      }
  case pb.MsgStorageApplyResp:
  ```
- commitIndex and appliedIndex both concern the entries from (stable) storage, right? unstable storage is the immediate storage mechanism that activates as a result of client requests, right? then, as entries are committed (which essentially means 'being written to WAL'), unstable storage is shrinked and commitedINdex updated; then, after committed entries are applied to the state machine (etcd's MVCC store), raft's applyIndex is also updated. is this thought process correct?
  ```go
  type raftLog struct {
      storage Storage
      unstable unstable
  ```
- 'by "advances internal bookkeeping" you mean that messages are added to rn.stepsOnAdvance, following that they will be processed when Advance() is called from within etcd realm. is my reasoning correct?
- when can lo >= hi?
  ```go
  lo, hi := l.applying+1, l.maxAppliableIndex(allowUnstable)+1 // [lo, hi)
  ```

## WAL & Log Entries

- in a leader context, I recall that writing to WAL happens in parallel to sendApp broadcast to followers in order to speed things up. where is that part of the code?
- isn't this dangerous? what if leader writes to WAL successfully, but does not get majority? that WAL entry will be intrusive and not useful
- still not clear. if leader writes successfully to its WAL and this entry is not present on the follower's WAL (i.e. leader is isolated due to network partition), when the network is again reunited, what happens to that forlorn entry?
- if the entry before E is committed, E is not committed, and entry E + 1 is committed, will this not mean that E will also be included?
- ok, but E will exist on the machine. how can it be avoided when considering the cluster state?
- 'L truncates it'.. so this is a wal entry itself? essentially cancelling the stale 'E' entry?

## Go Language

- what does [:i:i] slice syntax do?
- 'pipelining emphasizes staged structure' -- what is staged structure?
- what does 'rkvc' stand for?
