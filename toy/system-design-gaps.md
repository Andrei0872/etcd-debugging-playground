# System Design Gaps — Learning Plan

## Weak Points

### Back-of-envelope estimation
The practiced skill of sizing a system before designing it. Interviewers expect this upfront.

Search:
- "back of envelope calculation system design interview"
- "system design capacity estimation examples QPS storage bandwidth"
- "powers of 2 table system design latency numbers every programmer should know"
- "Jeff Dean latency numbers 2023"

Practice: for every system you design, estimate: daily active users → QPS → storage per day → memory per node → bandwidth. Do it in 2 minutes.

---

### Horizontal scaling patterns
How stateless services scale, and how state is managed when they do.

Search:
- "stateless vs stateful services horizontal scaling"
- "session management distributed systems sticky sessions vs token"
- "database read replica lag consistency tradeoffs"
- "horizontal vs vertical scaling when to use each"
- "sharding strategies range vs hash vs directory"
- "hotspot problem sharding"

---

### API design decisions
When to use which protocol and how to design the interface itself.

Search:
- "REST vs gRPC vs GraphQL tradeoffs when to use"
- "REST API pagination cursor vs offset"
- "API versioning strategies URL vs header"
- "idempotency keys API design"
- "API rate limiting design patterns"

---

## Not Covered At All

### Consistent hashing
Essential for cache clusters and distributed databases — how to add/remove nodes without rehashing everything.

Search:
- "consistent hashing explained with virtual nodes"
- "consistent hashing vs modulo hashing"
- "consistent hashing real world use cases DynamoDB Cassandra"
- "rendezvous hashing vs consistent hashing"

---

### Rate limiting algorithms
Almost always asked. Know all four and their tradeoffs.

Search:
- "token bucket vs leaky bucket algorithm"
- "sliding window counter rate limiting"
- "fixed window vs sliding window rate limiting tradeoffs"
- "rate limiting distributed systems Redis implementation"
- "Stripe rate limiting blog"
- "Cloudflare rate limiting architecture"

---

### Caching patterns
Cache placement, invalidation, and consistency.

Search:
- "cache aside vs read through vs write through vs write behind"
- "cache invalidation strategies TTL vs event-driven"
- "thundering herd problem cache"
- "cache stampede prevention"
- "Redis data structures use cases sorted set leaderboard"
- "eviction policies LRU LFU FIFO when to use"
- "CDN cache invalidation"

---

### Message queues and event streaming
Kafka's design is directly analogous to WAL + watch — you already understand the primitives.

Search:
- "Kafka architecture log based message queue"
- "Kafka consumer groups partition assignment"
- "at least once vs exactly once vs at most once delivery"
- "Kafka vs RabbitMQ when to use"
- "outbox pattern event driven architecture"
- "event sourcing vs traditional CRUD"
- "backpressure in message queues"

Note: Kafka's append-only partition log is structurally identical to etcd's WAL. Consumer offset = applied index. Partition leader = Raft leader.

---

### Search systems
How full-text search works at scale.

Search:
- "inverted index data structure explained"
- "TF-IDF vs BM25 ranking"
- "Elasticsearch architecture shards replicas"
- "typeahead autocomplete system design"
- "search system design interview"

---

### Multi-region and global distribution
The hardest class of problems — consistency across geography.

Search:
- "multi-region replication active active vs active passive"
- "conflict resolution distributed systems last write wins CRDT"
- "geo-routing latency based routing"
- "global distributed database CockroachDB design"
- "CAP theorem real world tradeoffs"
- "PACELC theorem"

Note: you already understand CAP deeply from the Raft context. PACELC extends it — learn that next.

---

### Object storage
S3-like systems — metadata vs data separation, large file handling.

Search:
- "object storage vs block storage vs file storage"
- "S3 architecture design internals"
- "design file storage system like Dropbox system design"
- "chunking large files distributed storage"
- "erasure coding vs replication storage tradeoffs"

---

### Classic interview problems
These are practiced formats. Each has an expected decomposition structure.

Problems to study (search each + "system design"):
- "URL shortener system design" — good intro, covers hashing, redirects, analytics
- "design Twitter feed / news feed" — fan-out on write vs fan-out on read
- "design rate limiter system design" — applies rate limiting algorithms above
- "design notification system" — push vs pull, mobile vs email vs SMS
- "design a distributed cache" — consistent hashing + eviction + replication
- "design a web crawler" — BFS, politeness, deduplication
- "design a key-value store" — you know this deeply already; practice articulating it
- "design a chat system like WhatsApp" — websockets, presence, message ordering

General structure every answer should follow:
1. Clarify requirements (functional + non-functional)
2. Capacity estimation (QPS, storage, bandwidth)
3. API design
4. Data model
5. High-level components
6. Deep dive into bottlenecks
7. Failure modes and mitigations
