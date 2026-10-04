# etcd Debugging Playground

A personal playground for digging into etcd/Raft internals (MVCC, BoltDB, watch, WAL, etc.) via debugging and experimentation.

## Notable directory

- [`toy/questions/`](toy/questions/): checkpoints of questions asked while learning, extracted periodically. The purpose is to check my understanding by re-anwering them as I progress in my journey.

## Debugging prerequisites

1. `dlv`: install via
```bash
go install github.com/go-delve/delve/cmd/dlv@latest

```
2. Editor configuration. For Neovim, see [this dap.lua config](https://github.com/Andrei0872/dotfiles/blob/5ffb0a645aec8695ce7b10e59c285abc7381a3f7/nvim/after/plugin/dap.lua#L151-L159)
