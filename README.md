# Under the Hood

Investigations into the internals of systems I study. Each one answers a single question with a diagram, a source-code walkthrough video, and a short write-up.

## Repository layout

- `<tool>/`: one folder per studied tool, containing one folder per investigation.
- `<tool>/_upstream/`: the tool's source, pinned as a git submodule.
- `<tool>/_patches/`: local changes applied on top of upstream to make debugging practical.
- `<tool>/_scripts/`: shared scripts, such as cluster setups.
- `<tool>/_notes/`: personal study notes and question checkpoints.

## Setup

Clone **everything** (all tools):

```bash
git clone --recurse-submodules https://github.com/Andrei0872/under-the-hood.git
```

Clone **specific tools** (here, only etcd):

```bash
git clone https://github.com/Andrei0872/under-the-hood.git
cd under-the-hood
git submodule update --init etcd/_upstream
```

To add another tool later, run `git submodule update --init <tool>/_upstream`. Each tool's README covers the rest of its setup.
