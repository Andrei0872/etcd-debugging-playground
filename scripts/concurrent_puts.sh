#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
ETCDCTL="$REPO_ROOT/etcd/etcdctl/etcdctl --endpoints=http://localhost:2379 --command-timeout=30m --keepalive-time=1h --dial-timeout=30m"

$ETCDCTL put /foo 1 &
$ETCDCTL put /bar 2 &
wait
