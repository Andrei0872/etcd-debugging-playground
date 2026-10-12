#!/usr/bin/env bash
set -uo pipefail

# Scenario 5: leader election as a "singleton worker" pattern.
#
# Requires a running etcd — start it first with ./single-node.sh in
# another terminal.
#
# The problem: N replicas of some job (a cron sweep, a cache warmer,
# anything that must run on exactly one instance) all start up
# identically for availability, but only one of them may actually be
# "active" at a time. This is `concurrency.Election` (client/v3/concurrency
# /election.go) doing the same lowest-CreateRevision race as Mutex, just
# for "who's the leader" instead of "who holds the lock". We drive it via
# etcdctl's own `elect` command (etcdctl/ctlv3/command/elect_command.go),
# which is a thin wrapper around exactly that API — not a reimplementation.
#
# Demonstrates:
#   A. 3 candidates ("replicas") campaign for the same election; only one
#      wins, the other two block silently until they would be needed.
#   B. graceful shutdown (SIGTERM) of the leader -> campaign()'s signal
#      handler calls Election.Resign() itself -> near-instant failover.
#   C. a hard crash (SIGKILL, uncatchable) of the new leader -> no Resign()
#      runs -> the key only frees up once the underlying etcd lease
#      actually expires. `elect` has no --ttl flag (unlike `lock`), so
#      this rides concurrency.defaultSessionTTL = 60s as-is. That ~60s
#      stall IS the point: it's the real cost of an unclean exit versus a
#      clean one, and exactly why production leader-election consumers
#      care about handling SIGTERM/graceful shutdown at all.

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
ETCDCTL="$REPO_ROOT/etcd/_upstream/etcdctl/etcdctl --endpoints=http://localhost:22379 --command-timeout=30m --keepalive-time=1h --dial-timeout=30m"
ELECTION_NAME=singleton-job

c_hdr='\033[1;34m'; c_dim='\033[2m'; c_ok='\033[32m'; c_reset='\033[0m'

hdr()  { printf "\n${c_hdr}== %s ==${c_reset}\n" "$1"; }
note() { printf "${c_dim}%s${c_reset}\n" "$1"; }

if ! $ETCDCTL endpoint health >/dev/null 2>&1; then
    echo "etcd isn't reachable on localhost:22379 — start it first with ./single-node.sh" >&2
    exit 1
fi

$ETCDCTL del "$ELECTION_NAME" --prefix >/dev/null

REPLICAS=(replica-1 replica-2 replica-3)
LOGS=(/tmp/lease-demo-elect-1.log /tmp/lease-demo-elect-2.log /tmp/lease-demo-elect-3.log)
PIDS=()
OBSERVER_LOG=/tmp/lease-demo-elect-observer.log

cleanup() {
    for pid in "${PIDS[@]:-}" "${OBSERVER_PID:-}"; do
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
    done
    wait 2>/dev/null
}
trap cleanup EXIT

: > "$OBSERVER_LOG"
$ETCDCTL elect "$ELECTION_NAME" -l >> "$OBSERVER_LOG" 2>&1 &
OBSERVER_PID=$!

# find_leader_idx: among still-ALIVE candidates, whichever has a non-empty
# log is the current winner (Campaign() only prints once it wins, and a
# resigned/killed candidate's stale log from a PAST win doesn't count —
# that's why we gate on kill -0, not just "is the file non-empty").
find_leader_idx() {
    local i pid
    for i in 0 1 2; do
        pid="${PIDS[$i]:-}"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ -s "${LOGS[$i]}" ]; then
            echo "$i"
            return 0
        fi
    done
    return 1
}

wait_for_leader() {
    local tries=$1 idx
    for i in $(seq 1 "$tries"); do
        if idx=$(find_leader_idx); then
            echo "$idx"
            return 0
        fi
        sleep 1
    done
    return 1
}

# --- Part A: three candidates race ---------------------------------------
hdr "Part A: 3 replicas campaign for '$ELECTION_NAME'"

for i in 0 1 2; do
    : > "${LOGS[$i]}"
    $ETCDCTL elect "$ELECTION_NAME" "${REPLICAS[$i]}" >> "${LOGS[$i]}" 2>&1 &
    PIDS[$i]=$!
    echo "started ${REPLICAS[$i]} (pid ${PIDS[$i]})"
done

idx=$(wait_for_leader 15) || { echo "no leader elected in time" >&2; exit 1; }
echo
echo "leader: ${REPLICAS[$idx]} (pid ${PIDS[$idx]})"
note "  (won key, printed by 'elect':)"
sed 's/^/    /' "${LOGS[$idx]}"
note "  (observer saw:)"
sed 's/^/    /' "$OBSERVER_LOG"

# --- Part B: graceful shutdown --------------------------------------------
hdr "Part B: SIGTERM the leader — graceful shutdown"

old_idx=$idx
kill -TERM "${PIDS[$old_idx]}"
echo "sent SIGTERM to ${REPLICAS[$old_idx]}; its signal handler should call Election.Resign() itself"
wait "${PIDS[$old_idx]}" 2>/dev/null

new_idx=$(wait_for_leader 10) || { echo "no failover happened" >&2; exit 1; }
echo "new leader: ${REPLICAS[$new_idx]} — took over almost immediately (resign, not TTL expiry)"
note "  (observer saw:)"
sed 's/^/    /' "$OBSERVER_LOG"

last_idx=-1
for i in 0 1 2; do
    if [ "$i" != "$old_idx" ] && [ "$i" != "$new_idx" ]; then
        last_idx=$i
    fi
done

# --- Part C: hard crash ----------------------------------------------------
hdr "Part C: SIGKILL the new leader — unclean crash"

echo "killing ${REPLICAS[$new_idx]} with SIGKILL — uncatchable, no Resign() gets to run"
kill -KILL "${PIDS[$new_idx]}"
wait "${PIDS[$new_idx]}" 2>/dev/null

echo "'elect' has no --ttl flag, so this rides the default Session TTL (60s)."
echo "watching for up to 75s for ${REPLICAS[$last_idx]} to take over..."
for i in $(seq 1 15); do
    sleep 5
    if kill -0 "${PIDS[$last_idx]}" 2>/dev/null && [ -s "${LOGS[$last_idx]}" ]; then
        echo "t+$((i * 5))s: ${REPLICAS[$last_idx]} is now leader"
        note "  (observer saw:)"
        sed 's/^/    /' "$OBSERVER_LOG"
        break
    fi
    echo "t+$((i * 5))s: still no leader — waiting out the crashed leader's session TTL"
done

hdr "done"
