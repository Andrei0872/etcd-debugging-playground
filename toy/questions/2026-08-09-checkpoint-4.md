# Questions — Checkpoint 4 (2026-08-09)

_Extracted from conversation since: 2026-07-24_

---

## uber_applier / Apply Package

- I still dont understand why the uber applier -- `/Users/andrei/Documents/etcd-debugging-playground/etcd/server/etcdserver/apply/uber_applier.go` -- has 2 distinct phases: apply and dispatch; why can't they be merged in a single one phase?

---

## Storage Backend

- is the bucket containing all {revision_sub: []byte} pairs called 'key'?
  ```
  tw.tx.UnsafeSeqPut(schema.Key, ibytes, d)
  src: /Users/andrei/Documents/etcd-debugging-playground/etcd/server/storage/mvcc/kvstore_txn.go
  ```
- why is t.buf necessary?
  ```go
  func (t *batchTxBuffered) UnsafeSeqPut(bucket Bucket, key []byte, value []byte) {
      t.batchTx.UnsafeSeqPut(bucket, key, value)
      t.buf.putSeq(bucket, key, value)
  }
  src: /Users/andrei/Documents/etcd-debugging-playground/etcd/server/storage/backend/batch_tx.go
  ```
- how does UnsafeRange detect that it does not have enough results from the buffer?

---

## WAL

- why a read lock here (or, how is it actually spelled properly)? this entails that multiple w.save can happen concurrently?
  ```go
  func (st *storage) Save(s *raftpb.HardState, ents []*raftpb.Entry) error {
      st.mux.RLock()
      defer st.mux.RUnlock()
      return st.w.Save(s, ents)
  }
  ```
- when would cutting be necessary?
  ```go
  // cut closes current file written and creates a new one ready to append.
  // cut first creates a temp wal file and writes necessary headers into it.
  // Then cut atomically rename temp wal file to a wal file.
  func (w *WAL) cut() error {
  ```
- WAL seems pretty brilliant. are there any alternative solutions?
- wall-clock interval? what's that?

---

## Raft Node Loop & Transport

- from this point, how is the RPC message sent to other Raft peers? I cannot seem to figure this out
  ```go
  case pm := <-propc:
      m := pm.m
      m.From = new(r.id)
      err := r.Step(m)
  ```
- why m is sent in the next goroutine loop (via readych) and not immediately?
- how is MsgAppResp handled by the reader?
- raft library -- what do you mean that it knows only about message queuing?
- are heartbeats also sent via etcd's Raft loop? e.g. `@etcd/server/etcdserver/raft.go`
- interesting problem: how does etcd handle ticks when the same raft node receives a lot of traffic such that ticks don't have time to run? maybe that's why tickc is buffered?
- what does 'back-to-back' mean?

---

## Raft Protocol — Log Replication

- pb.MsgProp -- I understand that this message only exists when the client directly hits a raft node with requests. is this correct?
- what is MsgHup?
- in case multiple requests (PUT/GET/DELETE) reaches the same node, then u.entries could have length > 0?
  ```go
  func (u *unstable) maybeLastIndex() (uint64, bool) {
      if l := len(u.entries); l != 0 {
          return u.offset + uint64(l) - 1, true
      }
      if u.snapshot != nil {
          return u.snapshot.GetMetadata().GetIndex(), true
      }
      return 0, false
  }
  ```
- msgAfterAppend vs msgs? does msgs store messages that are to be sent to other raft nodes?
  ```go
  r.msgsAfterAppend = append(r.msgsAfterAppend, m)
  traceSendMessage(r, m)
  } else {
      if m.GetTo() == r.id {
          r.logger.Panicf("message should not be self-addressed when sending %s", m.GetType())
      }
      r.msgs = append(r.msgs, m)
  ```
- Message struct: Commit vs Index fields?
  ```
  /Users/andrei/go/pkg/mod/go.etcd.io/raft/v3@v3.7.0-rc.1/raftpb/raft.pb.go
  ```
- when this is called as a follower, it immediately advance commit index, although the data will be written to WAL eventually?
  ```go
  func (l *raftLog) maybeAppend(a logSlice, committed uint64) (lastnewi uint64, ok bool) {
  ```
- so, a follower, when, it receives MsgApp, it will call that maybeAppend fn. this will register a MspAppResp message which will be sent back to the leader AFTER the entry has been written to follower's WAL. correct?
- if a follower receives a PUT request, it will forward to the leader. then, leader will send a MsgApp to follower, and then the aforementioned flow happens again. is that correct?
- MspAppResp confirms persistence to WAL or to MVCC? does Match refer to applied or consistent index?
- on follower, why commitIndex <= Match?
- could Next be seen as a sort of optimistic update? meaning that it contains the next raft log index, basically next = crtRaftLogIndex + 1; is my understanding correct?
  ```go
  // Next is the log index of the next entry to send to this follower. All
  // entries with indices in (Match, Next) interval are already in flight.
  //
  // Invariant: 0 <= Match < Next.
  // NB: it follows that Next >= 1.
  //
  // In StateSnapshot, Next == PendingSnapshot + 1.
  Next uint64
  ```

---

## Raft Protocol — Flow Control & ProgressTracker

- elaborate on this optimisation? why [7]?
  ```go
  // We need to sort the IDs and don't want to allocate since this is hot code.
  // The optimization here mirrors that in `(MajorityConfig).CommittedIndex`,
  // see there for details.
  /Users/andrei/go/pkg/mod/go.etcd.io/raft/v3@v3.7.0-rc.1/tracker/tracker.go
  ```
- is trk tracker.ProgressTracker also kept in sync in each raft node?
  ```go
  trk tracker.ProgressTracker
  /Users/andrei/go/pkg/mod/go.etcd.io/raft/v3@v3.7.0-rc.1/raft.go
  ```
- why are these recorded?
  ```go
  pr.SentEntries(len(ents), uint64(payloadsSize(ents)))
  pr.SentCommit(r.raftLog.committed)
  src: /Users/andrei/go/pkg/mod/go.etcd.io/raft/v3@v3.7.0-rc.1/raft.go
  ```

---

## Raft Protocol — Election & Membership

- btw, wasn't election timeout supposed to be random, as per Raft paper?
- heartbeat interval vs election timeout?
- what is that >= 5x rule?
- when can this happen?
  ```go
  if r.trk.Progress[r.id] == nil {
      // If we are not currently a member of the range (i.e. this node
      // was removed from the configuration while serving as leader),
      // drop any new proposals.
      return ErrProposalDropped
  }
  ```

---

## etcd Architecture

- etcd relies on raft library... technically, i visualize 3 different responsiblity areas within etcd: 1. etcd server... 2. raft... 3. etcd-raft bridge... is this correct? then, how would nr 3 more idiomatically called? a shim?
- for some reason, it always takes the PUT requests one by one in committedEntries; [why?]
- how should I make the requests such that both entries are committed at once? i.e. committedEntries to contain multiple items?

---

## Production Operations & etcd Cluster

- in practice, in a prod environment, is it expected for etcd clients (k8s controllers via kube-apiserver) to talk to specific etcd cluster nodes? or is something like etcd-gateway or grpc-proxy being used? do the latter 2 guarantee that leader is reached? does it really matter if leader or follower is reached first?
- linearizable reads mean that wall-clock requests match the results? and the leader is the only source of truth because a leader will always contain the most up to date state?
- is there a way (e.g. via etcdctl) to query the cluster and find out which node is the leader?
- how can i increase election time?

---

## etcdctl & Shell

- can I use `./etcdctl ...; ./etcdctl..` to run 2 PUT commands in parallel?
- could I not use `||`? what is `;` called?
- how are `--listen-client-urls` and `--advertise-client-urls` different?
  ```
  --listen-client-urls=http://localhost:2383 \
  --advertise-client-urls=http://localhost:2383 \
  ```
