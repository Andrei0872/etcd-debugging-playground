#!/usr/bin/env bash
set -euo pipefail

# Single-node etcd under dlv — for observing AND breakpointing lease
# behavior (TTL/keepalive, multi-key revocation, mutex fair-queue). For
# scenarios that need to watch the primary lessor migrate across a leader
# failover, use ../3-node-cluster.sh (3-node) instead.
#
# Runs on 22379/22380 (not 2379/2380) so it can coexist with ../3-node-cluster.sh.
# dlv listens headless on :2348 (3-node-cluster.sh uses 2345/2346/2347) — attach
# with `dlv connect :2348` or point your IDE's remote-debug config at it.
# No --continue: dlv sits paused before the server starts running, so you
# have time to set breakpoints before letting it go. Good starting points
# for lease scenarios:
#   server/lease/lessor.go:Grant / Revoke / expireExists / findExpiredLeases
#   server/etcdserver/api/v3rpc/lease.go:LeaseGrant / LeaseKeepAlive

# Note: deliberately NOT setting --election-timeout/--heartbeat-interval
# large (unlike 3-node-cluster.sh). Those exist there to stop OTHER peers from
# timing out a paused node in a quorum — irrelevant for a single member.
# They'd cost us here: etcd derives lessor.MinLeaseTTL as
# (3*ElectionTicks/2)*heartbeat (server/etcdserver/server.go:340), so
# 3-node-cluster.sh's 50s/5s pair forces every lease to at least 75s TTL, which
# would silently stretch every scenario. Defaults (~1000ms/100ms) keep
# MinLeaseTTL at ~1.5s so short demo TTLs (e.g. 5s) are honored as-is.

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
ETCD_SRC="$REPO_ROOT/etcd/_upstream"
DATA_DIR=/tmp/etcd-lease-data

rm -rf "$DATA_DIR"

cd "$ETCD_SRC"

# dlv --headless spawns debugserver (lldb) as a child, which in turn spawns
# the actual etcd binary being debugged (__debug_bin*) as ITS child — three
# separate processes. Killing just the top-level dlv (e.g. plain Ctrl-C)
# leaves the other two running as orphans, still holding :22379/:22380.
# kill_tree walks and kills the whole descendant chain so Ctrl-C actually
# tears everything down.
kill_tree() {
    local pid=$1 child
    for child in $(pgrep -P "$pid" 2>/dev/null); do
        kill_tree "$child"
    done
    kill -TERM "$pid" 2>/dev/null || true
}

dlv debug ./server/main.go --headless --listen=:2348 --api-version=2 --accept-multiclient -- \
    --name=etcd-lease \
    --data-dir="$DATA_DIR" \
    --listen-client-urls=http://localhost:22379 \
    --advertise-client-urls=http://localhost:22379 \
    --listen-peer-urls=http://localhost:22380 \
    --initial-advertise-peer-urls=http://localhost:22380 \
    --initial-cluster="etcd-lease=http://localhost:22380" \
    --initial-cluster-state=new \
    > >(awk '{ print "\033[36m[etcd]\033[0m " $0; fflush() }') 2>&1 &
DLV_PID=$!

trap 'kill_tree "$DLV_PID"' EXIT

wait "$DLV_PID"
