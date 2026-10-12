# dlv halts the target at entry by default — cluster wouldn't start without a breakpoint

## Symptom

`scripts/cluster.sh` launches 3 nodes, each under its own `dlv debug --headless
--accept-multiclient` instance, debugged from 3 separate neovim (nvim-dap)
instances. The cluster only formed successfully when a breakpoint was set (and
hit) during the very first initialization — without one, it silently never
came up.

## Root cause

`dlv debug` (headless or not) compiles and execs the target binary, but halts
it *at the entrypoint* before any of its code — including `main()` — runs.
The debug server then opens its listen port and waits for a client to
connect. Attaching a client does not resume execution by itself: the process
stays frozen until the client explicitly sends a `continue` request.

For `cluster.sh`, this meant every one of the 3 etcd processes was parked
before it ever bound its client/peer URLs (2379–2384) — nothing was
listening, nothing was reachable. `--initial-cluster-state=new` bootstrap
requires all initial members to complete a handshake over their peer URLs
before raft even starts, so the cluster can't form until *all three* have
actually started running.

Setting a breakpoint wasn't the real requirement — it was incidental. The
actual trigger was issuing `continue` on each of the 3 sessions, which
happens naturally as part of a "set breakpoint → attach → continue → hit
it" workflow. Skipping the breakpoint meant skipping the reflexive
`continue`, so the processes just sat halted forever and the cluster looked
like it never started.

## Why halt-on-entry is dlv's default

This isn't an etcd-specific quirk, it's standard debugger behavior (same
model as `gdbserver`, `lldb-server`, etc.), for a few reasons:

- **You need a chance to set up state before anything happens.** If the
  target ran freely the instant it launched, you'd have no window to set
  breakpoints, watchpoints, or inspect initial state before code you care
  about (e.g. early init logic) has already executed and possibly raced
  past. Halting at entry guarantees the debugger is in control from the very
  first instruction.
- **Attach/launch is decoupled from execution on purpose.** The DAP model
  (and dlv's own client protocol) treats "start/attach the process" and "let
  it run" as two distinct steps so tooling (like nvim-dap) can finish
  configuring the session — set breakpoints, exception filters, etc. — via a
  `configurationDone`-style step *before* the program's first instruction
  executes. If launch implied immediate execution, any breakpoints you meant
  to set "at the start" could already be missed.
- **Headless mode doesn't change this contract.** `--headless
  --accept-multiclient` only changes *how* a client connects (over a
  socket, potentially reconnecting), not *when* the target starts running.
  The halt-until-continue behavior is orthogonal to that — it's about
  keeping the debugger authoritative over program execution from the start.
- **dlv provides an explicit escape hatch for exactly this case:** `dlv
  debug --continue` tells dlv to resume execution immediately after launch,
  without waiting for a client to connect and continue manually. The process
  still stops normally on any breakpoint you set later — you're just opting
  out of the *initial* halt, which is what a multi-process setup like this
  cluster needs (three independently-launched processes that must all reach
  their listen state before the group can make progress together).

## Fix

Added `--continue` to each `dlv debug` invocation in `scripts/cluster.sh`.
Now all three etcd nodes run immediately on launch and reach their
peer/client listeners without needing a manual per-session `continue` first.
Breakpoints set later still pause execution as normal — `--continue` only
affects the initial entry halt.
