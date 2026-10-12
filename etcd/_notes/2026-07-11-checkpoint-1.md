# Questions — Checkpoint 1

All questions extracted from conversation start through 2026-07-11.

---

## Raft Library

- `func (r *raft) applyConfChange` — what does it do?
- `incoming`? `outgoing`? (re: `JointConfig [2]MajorityConfig`)
- `func (rn *RawNode) Bootstrap(peers []Peer) error` — having a difficult time understanding what's going on here
- `raftStatusMu.Lock()` — why a lock here? could it not simply be returned?
- `becomeFollower(term=1)` — is this a convention or a hack?
- `func (r *raftNode) start(rh *raftReadyHandler)` — is this the place where etcd server and raft domains establish communication?
- Before the leader writes, it must have the majority from other peers — where is this checked?
- Followers must first commit and THEN send MsgAppResp, right?
- `MsgAppResp{index=lastIndex}` — is this the last appliedIndex or last committedIndex?

## WAL & Snapshots

- What data lies in WAL?
- Why is snapshot metadata saved to WAL?
- Which part of the earlier process writes to WAL?
- Why committed entries are applied (written to bolt) only in the NEXT iteration?
- `if err := r.storage.Save(rd.HardState, rd.Entries)` — why doesn't the program exit after a fatal error?

## BoltDB / Backend

- Why does `batchTxBuffered` need a `buf` field?
- What about `bucket2seq`?
- `readTx` has an `RWMutex` — why a RW mutex on a readonly txn?
- `func (txw *txWriteBuffer) writeback(txr *txReadBuffer)` — what's this for?
- `func (t *batchTxBuffered) Commit()` — when called from the backend loop, `t.Unlock()` only releases the lock, right? Mutex.Unlock() would suffice?
- `func (t *batchTx) safePending() int` — why is `pending` guarded by a lock? what's the concurrent danger?
- Could not atomic be used instead of a lock for `pending`?
- Show me where the caller of `UnsafePut` holds the lock
- Just to make sure — the caller holds the very same lock used for `safePending()`?
- `func (t *batchTx) Unlock()` — why would there be a batch limit?
- `if t.backend.readTx.tx != nil { go func(tx *bolt.Tx, wg *sync.WaitGroup) { wg.Wait(); tx.Rollback() } }` — why rollback on a read txn?
- `atomic.StoreInt64(&b.size, size)` — why atomics here? could `begin()` ever be called concurrently?
- `commit()` calls `t.backend.readTx.Lock()` — no commit happens until all readers OR writers release their RWMutex lock?
- What if, while the old snapshot is still there, multiple concurrent readers spawn again?
- Is it correct that there could be multiple old snapshots of concurrent readers?
- Is it rightfully said that boltdb belongs to the data layer of etcd?
- More rigorously: boltdb = persistence layer; MVCC store = data model layer; WAL = ?
- What exactly does 'data model layer' mean?
- Does etcd make use of bolt's MVCC? isn't there only one read and one write transaction?
- `type batchTx struct { sync.Mutex ... }` — can an instance call `Lock()` directly since `sync.Mutex` is embedded?

## MVCC & Watchers

- `go s.syncWatchersLoop()` / `go s.syncVictimsLoop()` — what are these?
- What happens at line 244 in `syncWatchersLoop()`? Examples please.
- Is there a maximum of watchers supported?
- What if etcd server goes down — are watchers recoverable?
- Do watchers connect to leader or follower?

## ConsistentIndex

- Is `ConsistentIndex` modified as part of the UberApplier update chain?
- Not yet clear when `consistentIndex` is updated
- Your initial explanation was vague and imprecise (re: defer writing to bbolt)

## UberApplier & Apply Pipeline

- `srv.uberApply = srv.NewUberApplier()` — tell me more about it
- What is this wrapping pattern called?
- Is `Put()` passed down 2 times? is it because `Put()` and `Apply()` need to be 'transactional'?
- What is the connection between FIFOScheduler and UberApplier?
- `func (t *batchTx) LockInsideApply()` — in which cases is this applied?
- `ValidateCalledOutSideApply(t.backend.lg)` — what's this? (in context of batchTx)
- `tx.Lock(); enabled := tx.UnsafeReadAuthEnabled()` — why locking?
- Calling `ForceCommit()` before `tx.Unlock()` will lead to a deadlock?
- Why would you want to update `consistentIndex` during an Auth Write? it does not concern raft at all
- `func (b *backend) SetTxPostLockInsideApplyHook(hook func())` — is `func()` a type covering all functions?
- `applyc <- ap` will trigger FIFOScheduler, right? why does this happen so early?
- An apply batch refers to multiple FIFOScheduler jobs OR one job that handles a batch?
- `Schedule()` goroutine == the one in `etcdserver.run()`?

## Linearizable Reads & ReadIndex

- Elaborate on serializable reads vs linearizable reads
- What does serializable mean in the database sense?
- Remind me what ReadIndex was?
- `s.read = read.NewRead(s, &s.r)` — what is this?
- Client side — you mean etcdserver's main go `run()`?
- What is ReadIndex? (re-asked)
- Why does read-your-own-writes ensure linearizability? isn't linearizability a global trait?
- RYOW — I'd assume this appears in context of concurrent systems. In which cases do you write foo and then immediately need to read it?
- Elaborate on what 'read-your-own-writes' actually means
- `ConcurrentReadTx` — is it replicated in the cluster?
- Will stale data be served on node B, or will B wait until `appliedIndex >= commitIndex`?
- Does applying entries until `appliedIndex >= commitIndex` also update `ConcurrentReadTx`?
- With the write buffer, isn't strong consistency kind of violated?
- RYOW being a consequence of linearizability does not make sense — they are orthogonal

## Wait / applyWait

- `s.w = wait.New()` / `s.applyWait = wait.NewTimeList()` — what are these?
- Why does the sharding trick work? why 64 shards and not more?
- `Wait(N)` after `Trigger(N)` — when can this happen?

## Server Startup & Bootstrap

- `func (e *Etcd) servePeers()` — why is cmux used here? it seems only one http server is instantiated
- Raft peers communicate with RPC via HTTP — HTTP/1.1 or HTTP/2?
- `func (e *Etcd) startHandler(handler func() error)` — why this?
- `notifySystemd(lg)` — why this?
- In which systems can etcd be run as a systemd service? and why?
- `m := cmux.New(sctx.l)` — why does cmux.New need a listener?
- Let's say I spawn a cluster — when does a node propose the ConfChange?
- When instantiating a cluster for the first time, all cluster-data can be inferred from given configuration — peers need not communicate for initialisation data?

## HTTP / gRPC / cmux

- etcdserver is basically 2 servers: HTTP (HTTP/1.1) and gRPC (HTTP/2)?
- `e.errc = make(chan error, len(e.Peers)+len(e.Clients)+2*len(e.sctxs))` — why `2*`?
- What exactly is `serveCtx`? why is unsecure connection supported?
- `func configureHTTPServer` — you got it wrong, it uses HTTP/2 not HTTP/1.1
- `[http server for clients code snippet]` — HTTP/2 is preferred separately for the gRPC branch
- Why does `ServeHTTP` not get reached when invoking `etcdctl put /foo 6`?
- Why does `ServeHTTP` handle grpc-gateway? or does it differ from etcd-gateway?
- What are the files where `etcdctl put` and `etcdctl get` are invoked (on the server)?
- `/Users/andrei/Documents/etcd-debugging-playground/etcd/api/etcdserverpb/rpc_grpc.pb.go` — from which `.proto` file is this generated?
- `return srv.(KVServer).Put(ctx, req.(*PutRequest))` — is `srv.(KVServer)` type casting?
- `func NewQuotaKVServer` — is this called the decorator pattern?
- What exactly generates `type KVServer interface`?
- How does protoc know to add `context.Context` to `Put()` and `Range()`?
- What is unary RPC? is `protoc-gen-go-grpc` a plugin for protoc? can I create my own plugins?
- What does `protoc-gen-go` do compared to `protoc-gen-go-grpc`? and `protoc`?
- Does `protoc-gen-go` make sense on its own? what is serialisation?
- Does etcd implement rate limiting? is that what `quotaKVServer` is doing?
- Does Kafka/Redis use protobufs? why does etcd encode data using protobufs? elaborate on 'cache serialized in memory'. what is variable-length encoding? why is rate limiting handled by a sidecar?
- What is a client? what is `clientv3`?
- Re `clientv3`: client-level load balancer — what do you mean it handles leader discovery?
- etcd data files == db file (BoltDB), WAL files and snapshot files?
- What exactly is etcdctl?
- What are the main components of etcd?
- What if a client sends a request to a follower?
- How can I send a request to the current open server the way kube-apiserver would?
- Which k8s components communicate with etcd server?
- How can I invoke etcdctl from this local repo clone?
- What is AuthN/AuthZ?

## Peer Transport & Networking

- `tr := &rafthttp.Transport{...}` — why is this created? wasn't a `peerRt` created before?
- `t.pipelineProber` / `t.streamProber` — what is a prober?
- What is chunked transfer encoding? why does Raft rely on this?
- Raft peers don't actually use TLS, right? and regarding 'peer stream is literally one logical stream' — there is also the fact the order of streamed messages is important, right?

## GoAttach & Shutdown

- `func (s *EtcdServer) GoAttach(f func())` — explain the magic
- Add the GoAttach shutdown race answer to an md file under insights/
- `s.leaderChanged = notify.NewNotifier()` — why is this at etcd level? for Raft, it's obvious
- What is each of these GoAttach() goroutines responsible for?
- `adjustTicks` — why is it part of etcd layer? isn't it supposed to be a Raft concern?
- What is the purpose of `adjustTicks`?
- I cannot identify `adjustTicks` in pprof/goroutine — why?

## FIFOScheduler

- `var todo Job; f.mu.Lock(); if len(f.pendings) != 0 { todo = f.pendings[0] }; f.mu.Unlock()` — why behind a lock?

## Lease

- `srv.lessor = lease.NewLessor(...)` — what is this? what problem do leases solve?
- `defaultLeaseCheckpointInterval = 5 * time.Minute` — what is this?
- What is a 'grant'?
- What does it mean for a lease to be renewed?
- Re leader election — wasn't it Raft-specific? it seems now part of etcd concerns?
- Is lease TTL also persisted to Raft log (WAL)?
- Leasing is app-specific — but why would kube-ctrl-manager and kube-scheduler compete?
- `minTTL := time.Duration((3*cfg.ElectionTicks)/2) * heartbeat` — why 3/2?

## Distributed Systems Concepts

- P(at least one of 100 requests hits p99) = 1 - (0.99)^100 ≈ 63% — elaborate. why ^100? why '1 minus'?
- What is fan out? why does it multiply tail latency?
- P(at least one of 33 requests hits p99 on node 1) — the 2nd probability would be 1/3 * 28%?
- What is wall clock time?
- What is active-passive high availability pattern?
- Split brain — if both schedulers think they are active, could state inconsistency happen?
- What is optimistic concurrency? how does etcd use this?
- What is compare-and-swap?
- What are some lock-free data structures?
- What different approaches do other distributed databases use?
- How complex would CockroachDB be to explore compared to etcd?
- What about Redis? could it be distributed?
- What is a gossip protocol?
- Why logN to reach the whole cluster? why is eventual consistency acceptable in Redis?
- Is 'gossip' an actual protocol or something?
- etcd is 'clever' and uses Raft not just for user-facing resources but also for internal state (auth, members, mvcc, lease)?
- Lease was not part of the Raft paper — by persisting lease checkpoints to Raft log, it's shared by all Raft members, right?
- How does Raft work? (re: blog post) — I don't agree with HA claim per CAP theorem
- What does it mean that 'my reading is sharper' — does it mean I took it too literally?
- What is TSDB? is a Prometheus server embedded in etcd via promhttp.Handler()?
- In a prod environment, Prometheus metrics are no longer stored in memory, right?
- What is the metrics endpoint (URL)?
- `http://localhost:2379/metrics` — this actually works
- `promhttp.Handler()` — where is this data stored? from where is it written? what is the proxy url?

## Go Runtime / Concurrency

- Is there a way to visualise the existing goroutines?
- Can I see goroutines in my neovim DAP setup?
- `http://localhost:2381/debug/pprof/goroutine?debug=2` does not work — 404
- `goroutine 152 [select, 2 minutes]` — what's in `[]`?
- What does 'pprof' mean?
- trace vs pprof?
- go trace: what is the difference between trace by proc and trace by thread?
- How many goroutines are spawned in total for a functional etcd server?
- Why is thread context switch of 1-10 microseconds considered expensive?
- Where is a goroutine state saved?
- 'the actual data being processed dwarfs the stack overhead' — what do you mean?
- Why will thread pooling lead to 'roughly' and not 'exactly'? how does thread pooling help?
- `GC scan time ∝ amount of live memory` — what is that symbol?
- Are there synthetic examples on the internet where Go→Rust improvement was clearly visible?
- What is the GMP model?
- What exactly does 'tight CPU loop' mean? what about 'CPU-bound'?
- What do you mean by '10% efficiency'?
- What is M:N threading?
- What is a work-stealing scheduler? this is different from Rust's async primitives, right?
- Go uses CSP style via goroutines. Rust uses state machines — does this state machine pattern have a more canonical name?
- Are there resources online to read about Go's design principles (CSP)?
- Go CSP becomes 'Communicating Sequential Goroutines' — Goroutines instead of Processes, right?
- 'Actor model can also be useful for implementing background tasks, e.g. purgeFile' — right?
- What open file descriptors are you talking about?
- `monitorClusterVersion` — is it like a blue-green deployment?
- Local backend consistency — how can local backend diverge?
- `'(plus mmap handles)'` — what do you mean?
- Little's Law — elaborate
- Why is it called 'exponentially' in EWMA? where is the exponential part?
- Percentile estimation — what's what? what is Netflix's HdrHistogram?
- What is a 'scheduled closure'? does this pattern have a canonical name?
- Is 1000 ops/second a lot?
- Where have you taken those benchmark numbers from?

## Protocol Buffers / gRPC

- `bytes data = 1` in protobuf — what is this?
- Why `<< 3` in protobuf tag encoding?
- What is serialisation?
- What is variable-length encoding?

## expvar / debug

- What is `/debug/vars`? what is expvar? what about `init()`?
- How could you tell `raftStatus` is registered with expvar?
- expvar — I suppose it's disabled for prod builds, right?

## Sidecar / mTLS

- Talk more about the sidecar pattern
- mTLS — what's that?
- In which scenario would etcd be used with a sidecar?

## Miscellaneous

- `func (b *backend) SetTxPostLockInsideApplyHook(hook func())` — is `func()` a type covering all functions?
- `ls -l snap/db` — what does each column indicate?
- What is AuthN/AuthZ?
- What exactly is etcdctl? a quick way to simulate an etcd client?
- What is clientv3?
- Does Kafka/Redis use protobufs?
- `'read-your-own-writes'` — I'd assume this appears in context of concurrent systems
- save base64 & continuation bytes in a md file under insights/
- What is 'continuation bytes'? how would we go about streaming a video?
- Why does base64 solve the problem that JSON does not have native bytes?
- Give me an example of arbitrary bytes that would not be valid JSON and how base64 saves the day
- `func (ac *accessController) ServeHTTP` — why not reached when invoking `etcdctl put /foo 6`?
