#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
ETCD_SRC="$REPO_ROOT/etcd"

INITIAL_CLUSTER="etcd1=http://localhost:2380,etcd2=http://localhost:2382,etcd3=http://localhost:2384"
ELECTION_TIMEOUT=50000  # 50s — large enough to survive breakpoints
HEARTBEAT_INTERVAL=5000  # 5s — must be <= election-timeout / 5

cd "$ETCD_SRC"

dlv debug ./server/main.go --headless --listen=:2345 --api-version=2 --accept-multiclient --continue -- \
    --name=etcd1 \
    --data-dir=/tmp/etcd-data1 \
    --listen-client-urls=http://localhost:2379 \
    --advertise-client-urls=http://localhost:2379 \
    --listen-peer-urls=http://localhost:2380 \
    --initial-advertise-peer-urls=http://localhost:2380 \
    --initial-cluster="$INITIAL_CLUSTER" \
    --initial-cluster-state=new \
    --election-timeout="$ELECTION_TIMEOUT" \
    --heartbeat-interval="$HEARTBEAT_INTERVAL" 2>&1 | awk '{ print "\033[36m[etcd1]\033[0m " $0; fflush() }' &

dlv debug ./server/main.go --headless --listen=:2346 --api-version=2 --accept-multiclient --continue -- \
    --name=etcd2 \
    --data-dir=/tmp/etcd-data2 \
    --listen-client-urls=http://localhost:2381 \
    --advertise-client-urls=http://localhost:2381 \
    --listen-peer-urls=http://localhost:2382 \
    --initial-advertise-peer-urls=http://localhost:2382 \
    --initial-cluster="$INITIAL_CLUSTER" \
    --initial-cluster-state=new \
    --election-timeout="$ELECTION_TIMEOUT" \
    --heartbeat-interval="$HEARTBEAT_INTERVAL" 2>&1 | awk '{ print "\033[35m[etcd2]\033[0m " $0; fflush() }' &

dlv debug ./server/main.go --headless --listen=:2347 --api-version=2 --accept-multiclient --continue -- \
    --name=etcd3 \
    --data-dir=/tmp/etcd-data3 \
    --listen-client-urls=http://localhost:2383 \
    --advertise-client-urls=http://localhost:2383 \
    --listen-peer-urls=http://localhost:2384 \
    --initial-advertise-peer-urls=http://localhost:2384 \
    --initial-cluster="$INITIAL_CLUSTER" \
    --initial-cluster-state=new \
    --election-timeout="$ELECTION_TIMEOUT" \
    --heartbeat-interval="$HEARTBEAT_INTERVAL" 2>&1 | awk '{ print "\033[33m[etcd3]\033[0m " $0; fflush() }' &

trap 'kill $(jobs -p)' EXIT
wait
