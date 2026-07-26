# Next Steps & Learning Path

## Uncovered Topics

- **Lease internals** — TTL mechanics, lessor goroutine, how checkpoints are replicated through Raft.
- **Joint consensus / ConfChange v2** — joint quorum transition (incoming/outgoing majority configs) was never unpacked.
- **Linearizable read loop end-to-end** — ReadIndex came up but the full path (client → `MsgReadIndex` → leader confirms → `appliedIndex >= readIndex` → serve) was never traced.
- **etcd quota and alarms** — what happens when BoltDB hits its size limit, how `quotaKVServer` enforces it, and the alarm mechanism.
- **defrag** — BoltDB fragmentation and how `etcdctl defrag` works internally.
- **kube-apiserver ↔ etcd contract** — how k8s maps resource versions to etcd revisions, how pagination works (`Continue` token), how kube-apiserver batches watches.
- **Operational topics** — backup/restore, member add/remove in a live cluster.

---

## Suggested Order for Going Deeper

1. **MVCC internals** — `watchStore`, `syncWatchersLoop`, victim watchers, full watch dispatch path. Completes the data layer picture.
2. **Linearizable read loop** — short, self-contained path. Ties together ReadIndex, `appliedIndex`, and the MVCC read transaction. Classic interview topic.
3. **3-node cluster** — do this *after* (1) and (2) so you have the mental model to interpret what you observe. Use `etcdctl endpoint status`, kill nodes, watch leader re-election, inject partitions.
4. **Tests with debugger** — `TestRawNodeProposeAndConfChange`, `TestLeaderElection`, `TestHandleMsgApp` in the raft library. Short, self-contained, cover every edge case. Read the test intent before stepping through.

---

## The Path

**etcd deeply → content creation → k8s**

Skills being built that transfer everywhere:

- **Distributed systems fundamentals** — consensus, linearizability, MVCC, CAP tradeoffs. etcd is one of the cleanest real-world implementations. Same patterns appear in CockroachDB, TiKV, Zookeeper.
- **Storage systems** — WAL, B+Tree, append-only logs, compaction. Directly maps to Kafka, RocksDB, Postgres WAL.
- **Go concurrency patterns** — channel pipelines, RWMutex tradeoffs, goroutine lifecycles, GMP model. etcd is one of the best Go codebases to study.
- **gRPC / protobuf at scale** — interceptor chains, gateway, streaming. Standard in any serious backend system.
- **Observability** — structured tracing, Prometheus instrumentation, pprof. Universal.
- **Operational intuition** — what breaks in production (quota exceeded, watch revision compacted, leader churn, slow WAL fsync). Knowing this separates someone who read the code from someone who can be called an expert.

**Content angle**: the topics with highest value are where the gap between official docs and what's actually happening is largest — Raft commit vs apply vs stable, why the in-memory B-tree exists alongside BoltDB, partition scenarios. These are underexplained in most etcd material.

**Why k8s after etcd**: k8s complexity is largely accidental (abstractions on abstractions); etcd's is essential (fundamental distributed systems problems). With the foundation, k8s becomes "how does k8s use these primitives" rather than learning from scratch.
