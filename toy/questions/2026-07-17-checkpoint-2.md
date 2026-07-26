# Questions — Checkpoint 2 (2026-07-17)

_Extracted from conversation since: 2026-07-11_

---

## Observability (Tracing & Prometheus)

- `ctx, span = traceutil.Tracer.Start(ctx, "put", trace.WithAttributes(attribute.String("key", string(r.GetKey()))))` -- is this distributed tracing?
- otel vs prometheus?
- if Prometheus scrapes /metrics, then who writes to /metrics?
- isn't it dangerous to keep accumulating prometheus data in memory? can it not occupy too much memory?
- in order to have Prometheus server (with TSDB), it requires spawning another process, right?
- is http/1.1 /metrics exposed by etcd server or by the prometheus package?
- reading this `traceReceiveMessage(r, m)` in raft.go. it seems it is a no-op for now. does it mean that raft library itself also enables distributed tracing?
- this should be disabled on prod, right? [re TLA+ tracing]
- why magnitude slower? show me the math [re TLA+ tracing overhead claim]

## Auth & Permissions

- why is Auth checked at this point? isn't it too late?
  ```go
  func (s *EtcdServer) processInternalRaftRequestOnce(ctx context.Context, r *pb.InternalRaftRequest) (*apply2.Result, error) {
      ...
      if r.Authenticate == nil {
          authInfo, err := s.AuthInfoFromCtx(ctx)
  ```
- where is that first gRPC interceptor run?
- what's the purpose of the UberApplier's auth applier?
- re authApplier: why wouldn't a user be allowed to write the key?
- ok, and if I get this right:
  ```go
  if r.Authenticate == nil {
      authInfo, err := s.AuthInfoFromCtx(ctx)
  ```
  does not perform auth, simply extracts the data that is to be passed to authApplier?
- how can permissions be defined?
- in the end, permissions are applied to keys, right? only keys?

## Raft Protocol

- hardstate vs softstate?
  ```go
  if softSt := r.softState(); !softSt.equal(rn.prevSoftSt) {
      return true
  }
  if hardSt := r.hardState(); !IsEmptyHardState(hardSt) && !isHardStateEqual(hardSt, rn.prevHardSt) {
  ```
- when can this happen?
  ```go
  } else {
      r.logger.Infof("raft.node: %x lost leader %x at term %d", r.id, lead, r.Term)
      propc = nil
  }
  ```
- `case readyc <- rd: n.rn.acceptReady(rd)` -- this is the only place where readyc channel sends values, right?
- what happens if I do `./etcdctl put /foo 6` and `./etcdctl put /foo 7` at the same time?
- what is responsible for ready batching? i don't understand how the 2 entries, which go through 2 different proposals, end up being batched. what batches the proposals in a single ready action?
- so, this batching effect -- Entries: [N, N+1] -- is non-deterministic. e.g. if, at iteration 2, readyc would win instead, then we'd have 2 different ready messages?
- also, this non-deterministic trait is also the reason why Ready{} message has both Entries and CommittedEntries?
- do followers write to their WAL before confirming to the leader? if so, if the leader crashes before committing, the newly selected leader will have all the latest data due to one of the raft's safety property?
- what if a client sends requests during leader election? I suppose the messages will be batched and clients will be on hold for a while.
- what do you mean that prior-term entries are committed only transitively?
- but, in this case X should not be committed because it did not have majority
- `stepsOnAdvance []*pb.Message` -- what does it do?

## WAL & Storage

- where are WAL files written to disk?
- this does not guarantee that data is written to disk?
  ```go
  func (w *WAL) saveEntry(e *raftpb.Entry) error {
      b := pbutil.MustMarshalMessage(e)
      rec := &walpb.Record{Type: new(EntryType), Data: b}
      if err := w.encoder.encode(rec); err != nil {
          return err
      }
      w.enti = e.GetIndex()
      return nil
  }
  ```
- `p.w.Write()` leads to `File.Write()`. however, this does NOT call `Sync()` on the file. should sync not be called as well, in order to ensure that is written to disk immediately?
- from `pw.pageOffset = (pw.pageOffset + pw.bufferedBytes) % pw.pageBytes` -- i understand that the current file can have at most 'pw.pageBytes' pages? or am I missing something?
- elaborate on WAL file pre-allocation (64MB, fragmentation, fsync cost predictability)
- what are torn writes?
- re PageWriter: why 128KB buffer? why would it be so slow (show math)
- fallocate vs mmap?
- `ents []*pb.Entry` (from MemoryStorage in storage.go) -- how much can this array grow?
- `s.w.Trigger(id, nil) // GC wait` -- what's this?
- why RLock and not Lock? what RLock actually means and implies?
  ```go
  func (st *storage) Save(s *raftpb.HardState, ents []*raftpb.Entry) error {
      st.mux.RLock()
      defer st.mux.RUnlock()
      return st.w.Save(s, ents)
  }
  ```

## Protobuf & gRPC

- it seems that r contains no fields like http headers, body, etc. why? is it because it's http/2 and not http/1.1?
  ```go
  func (s *quotaKVServer) Put(ctx context.Context, r *pb.PutRequest) (*pb.PutResponse, error) {
  ```
- why encoding in protobufs and not sending an unserialized value?
- i have a hunch that raft library also uses protobufs. why?
- does protobuf guarantee versioning?
- what are these protobuf comments called?
  ```go
  state         protoimpl.MessageState `protogen:"open.v1"`
  Term          *uint64                `protobuf:"varint,2,opt,name=Term" json:"Term,omitempty"`
  ```
- why is Crc a pointer? and what does it do?
  ```go
  rec.Crc = new(e.crc.Sum32())
  ```
- this looks clever. why returning a pointer to a primitive value? I see `Type *MessageType`.. however, why a pointer?
  ```go
  func (x MessageType) Enum() *MessageType {
      p := new(MessageType)
      *p = x
      return p
  }
  ```

## Go Language & Channels

- which one of the select branches will be evaluated first?
  ```go
  func (n *node) Advance() {
      select {
      case n.advancec <- struct{}{}:
      case <-n.done:
      }
  }
  ```
- so, sending a value to a nil channel won't panic or something in Go?
- 'removes from contention' -- what does it mean?
- this is a clever thing [nil channel gating]. is this pattern canonical in Go?
- what does 'gating' actually mean?
- is this fn called from multiple goroutines? that's why it's a lock in here?
  ```go
  func (ms *MemoryStorage) LastIndex() (uint64, error) {
      ms.Lock()
      defer ms.Unlock()
      ms.callStats.lastIndex++
      return ms.lastIndex(), nil
  }
  ```
- what is 'runaway growth'?
- is the last `()` a type assertion?
  ```go
  cloned[i] = proto.Clone(es[i]).(*pb.Entry)
  ```
- is Mutex a mutual-exclusive lock?

## Context (Go)

- not sure i understand this: why not string?
  ```go
  // Users of WithValue should define their own types for keys.
  func WithValue(parent Context, key, val any) Context {
  ```
- context.Values(): is struct{} preferred because it essentially points to a different memory address? or, how does go differentiate between `struct{}` and `struct{}`? BTW, what is `struct{}{}`? also, given your context example misusing strings, does it imply that context values are shared globally across a go program?
- 'boxed into an interface{}' -- what does it mean?
- what is type identity vs value? tell me more about it
- I see that iota can be used instead of struct{}. why?
  ```go
  const currentSpanKey traceContextKeyType = iota
  ```
- in a context chain, if a node cancels the context (e.g. due to context.WithTimeout expiring), will the entire chain cancel? or just the sublist?
- [looking at DAP context chain output] i understand that the root node is created by the gRPC library and it's a timer?
- isn't there a perf penalty to have so many chained contexts?
- why another timeout added at this stage, besides the gRPC timerCtx?
  ```go
  cctx, cancel := context.WithTimeout(ctx, s.Cfg.ReqTimeout())
  ```

## etcd Server & Debugging

- what is 'cluster topology'?
- elaborate on what is a lifecycle hook?
- for learning purposes, I want to increase this timeout and the initial gRPC timeout. I want to have time to navigate with the debugger. how can i configure both?
  ```go
  cctx, cancel := context.WithTimeout(ctx, s.Cfg.ReqTimeout())
  ```
- getting this timeout error -- what does it mean and how to fix?
  ```
  keepalive ping failed to receive ACK within timeout
  ```
