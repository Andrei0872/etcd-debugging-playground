# Under the Hood

Investigations into the internals of systems I study. Each one answers a single question with a diagram, a source-code walkthrough video, and a short write-up.

All walkthrough videos are on my [YouTube channel](https://www.youtube.com/@andreigatej6704/videos).

## Tools

* [etcd](etcd/README.md): the distributed key-value store behind Kubernetes, built on the [Raft consensus algorithm](https://raft.github.io/raft.pdf).

## AI use

This repository exists to understand in depth how software works, and to share that knowledge. The write-ups and diagrams are not AI-generated: they come from my own study and debugging. I use AI to correct grammar slips (such as "too" for "two") and to check my write-ups for technical correctness. The supporting tooling, such as scripts and setup docs, was built with AI assistance.

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

To add another tool later, run `git submodule update --init <tool>/_upstream`. Each tool's README links to its setup guide.
