# Under the Hood

Investigations into the internals of systems I study. Each one answers a single question with a diagram, a source-code walkthrough video, and a short write-up.

All walkthrough videos are on my [YouTube channel](https://www.youtube.com/@andreigatej6704/videos).

## Repository layout

```
<tool>/
├── README.md              # setup and index
├── <slug>.md              # one file per investigation
├── _assets/<slug>.excalidraw.svg
├── _scripts/              # shared scripts; <slug>/ for investigation-specific ones
├── _patches/              # changes on top of upstream that make debugging practical
├── _notes/                # personal study notes
└── _upstream/             # the tool's source, pinned as a git submodule
```

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
