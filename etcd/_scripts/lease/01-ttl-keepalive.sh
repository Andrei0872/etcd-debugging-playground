#!/usr/bin/env bash
set -uo pipefail

# Scenario 1: TTL expiry vs KeepAlive.
#
# Requires a running etcd — start it first with ./single-node.sh in
# another terminal.
#
# Demonstrates:
#   A. a key attached to a lease that nobody renews -> etcd deletes it
#      itself once the TTL elapses.
#   B. the same key kept alive via `lease keep-alive` -> it survives past
#      its original TTL, then vanishes the moment keepalives stop.
#
# A `watch` runs the whole time so you can see the DELETE event etcd
# fires the instant the lease expires — the same mechanism a service
# registry watcher relies on.

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
ETCDCTL="$REPO_ROOT/etcd/_upstream/etcdctl/etcdctl --endpoints=http://localhost:22379 --command-timeout=30m --keepalive-time=1h --dial-timeout=30m"
TTL=5

c_hdr='\033[1;34m'; c_dim='\033[2m'; c_ok='\033[32m'; c_bad='\033[31m'; c_reset='\033[0m'

hdr()  { printf "\n${c_hdr}== %s ==${c_reset}\n" "$1"; }
note() { printf "${c_dim}%s${c_reset}\n" "$1"; }

if ! $ETCDCTL endpoint health >/dev/null 2>&1; then
    echo "etcd isn't reachable on localhost:22379 — start it first with ./single-node.sh" >&2
    exit 1
fi

$ETCDCTL del /demo/no-keepalive >/dev/null
$ETCDCTL del /demo/with-keepalive >/dev/null

WATCH_LOG=/tmp/lease-demo-watch.log
: > "$WATCH_LOG"
$ETCDCTL watch /demo/ --prefix >> "$WATCH_LOG" 2>&1 &
WATCH_PID=$!
trap 'kill "$WATCH_PID" 2>/dev/null; wait "$WATCH_PID" 2>/dev/null' EXIT

show_watch_log() {
    if [ -s "$WATCH_LOG" ]; then
        note "  (watch saw: $(tr '\n' ' ' < "$WATCH_LOG"))"
        : > "$WATCH_LOG"
    fi
}

get_key() {
    local key=$1
    if val=$($ETCDCTL get "$key" --print-value-only 2>/dev/null) && [ -n "$val" ]; then
        printf "  %-24s ${c_ok}present${c_reset}  (value=%s)\n" "$key" "$val"
    else
        printf "  %-24s ${c_bad}gone${c_reset}\n" "$key"
    fi
}

# --- Part A: no keepalive -----------------------------------------------
hdr "Part A: lease with TTL=${TTL}s, never renewed"

LEASE_A=$($ETCDCTL lease grant "$TTL" | awk '{print $2}')
echo "granted lease $LEASE_A"
$ETCDCTL put /demo/no-keepalive "alive" --lease="$LEASE_A" >/dev/null
$ETCDCTL lease timetolive "$LEASE_A"

echo "watching the key for $((TTL + 3))s with no renewal..."
for i in $(seq 1 $((TTL + 3))); do
    sleep 1
    printf "t+%ds:\n" "$i"
    get_key /demo/no-keepalive
    show_watch_log
done

# --- Part B: with keepalive ----------------------------------------------
hdr "Part B: lease with TTL=${TTL}s, kept alive with 'lease keep-alive'"

LEASE_B=$($ETCDCTL lease grant "$TTL" | awk '{print $2}')
echo "granted lease $LEASE_B"
$ETCDCTL put /demo/with-keepalive "alive" --lease="$LEASE_B" >/dev/null

$ETCDCTL lease keep-alive "$LEASE_B" > /tmp/lease-demo-keepalive.log 2>&1 &
KEEPALIVE_PID=$!
echo "started 'lease keep-alive' in background (pid $KEEPALIVE_PID)"

RUN=$((TTL * 2))
echo "watching the key for ${RUN}s — it should survive past its ${TTL}s TTL..."
for i in $(seq 1 "$RUN"); do
    sleep 1
    printf "t+%ds:\n" "$i"
    get_key /demo/with-keepalive
    show_watch_log
done

echo
echo "killing the keepalive (pid $KEEPALIVE_PID) — simulates the client crashing"
kill "$KEEPALIVE_PID" 2>/dev/null
wait "$KEEPALIVE_PID" 2>/dev/null

echo "watching for $((TTL + 3))s — should now expire like Part A..."
for i in $(seq 1 $((TTL + 3))); do
    sleep 1
    printf "t+%ds:\n" "$i"
    get_key /demo/with-keepalive
    show_watch_log
done

hdr "done"
