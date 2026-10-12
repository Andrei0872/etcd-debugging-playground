# etcd

## Setup

1. Fetch the source and apply the debugging patches:

   ```bash
   git submodule update --init etcd/_upstream
   git -C etcd/_upstream apply "$PWD"/etcd/_patches/*.patch
   ```

2. Install [`dlv`](https://github.com/go-delve/delve):

   ```bash
   go install github.com/go-delve/delve/cmd/dlv@latest
   ```

3. Configure your editor to attach to a headless `dlv`. For Neovim, see [this dap.lua config](https://github.com/Andrei0872/dotfiles/blob/5ffb0a645aec8695ce7b10e59c285abc7381a3f7/nvim/after/plugin/dap.lua#L151-L159).

## Debugging patches

Breakpoints stall etcd long enough to trip its timeouts. Wherever a flag can't help, a patch in [`_patches/`](_patches/) does. Each patch file starts with the reason it exists.

| Patch | Why |
|---|---|
| [`0001-req-timeout-30m`](_patches/0001-req-timeout-30m.patch) | Requests paused at a breakpoint would time out after at most ~105s. `--election-timeout` is capped at 50s. |

Patches are applied to the working tree only, so the submodule always points at a real upstream commit. Run these commands from the repo root:

```bash
# apply all patches
git -C etcd/_upstream apply "$PWD"/etcd/_patches/*.patch
```

```bash
# revert all patches
git -C etcd/_upstream apply -R "$PWD"/etcd/_patches/*.patch
```

```bash
# create a patch from current edits, then add a "why" header above the first `diff` line
git -C etcd/_upstream diff -- <file>... > etcd/_patches/NNNN-<name>.patch
```

Keep one concern per patch, and don't let two patches touch the same file.
