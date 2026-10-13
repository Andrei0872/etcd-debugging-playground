---
name: investigation-template
description: Scaffold a new investigation write-up at <tool>/<slug>.md (tool inferred from the cwd, title derived from the kebab-case slug) from the repo's template (diagram, YouTube badge, Excalidraw link, Setup, empty How It Works). Use when the user wants to start a new investigation.
---

You are creating a new investigation file from [template.md](template.md).

## Arguments

`/investigation-template <slug> [video=<url>] [excalidraw=<url>] [script=<file>]`

| Argument | Required | Description |
|---|---|---|
| `slug` | yes | Investigation slug in kebab-case, e.g. `how-nodes-establish-communication` |
| `video` | no | YouTube URL |
| `excalidraw` | no | Shareable Excalidraw URL |
| `script` | no | Script under `<tool>/_scripts/` used in the video, e.g. `3-node-cluster.sh` |

If `slug` is missing, ask for it.

## Steps

1. **Infer the tool** from the current working directory: it is the first path component of the cwd relative to the repo root (`git rev-parse --show-toplevel`). For example, a cwd of `<repo>/etcd` or `<repo>/etcd/_scripts` gives `etcd`. If the cwd is the repo root, or its first component starts with `_` or `.`, ask which tool to use.

2. **Derive the title** from the slug in title case: split on `-` and capitalize the first letter of each word (`how-nodes-establish-communication` → `How Nodes Establish Communication`). Leave the rest of each word unchanged. Keep these words lowercase unless they are the first or last word: `a`, `an`, `the`, `and`, `but`, `or`, `nor`, `for`, `so`, `yet`, `as`, `at`, `by`, `in`, `of`, `off`, `on`, `per`, `to`, `up`, `via` (`debugging-a-local-cluster` → `Debugging a Local Cluster`).

3. **Refuse to overwrite.** If `<tool>/<slug>.md` already exists, stop and tell the user.

4. **Fill the placeholders** in `template.md`:

   | Placeholder | Value |
   |---|---|
   | `{{TITLE}}` | the derived title |
   | `{{SLUG}}` | `slug` |
   | `{{TOOL}}` | the inferred tool |
   | `{{VIDEO_URL}}` | `video`, else leave `{{VIDEO_URL}}` |
   | `{{EXCALIDRAW_URL}}` | `excalidraw`, else leave `{{EXCALIDRAW_URL}}` |
   | `{{SHORT_SHA}}` | `git -C <tool>/_upstream rev-parse --short=7 HEAD` |
   | `{{UPSTREAM_TREE_URL}}` | the submodule's URL from `.gitmodules`, without `.git`, plus `/tree/<full SHA>` |
   | `{{VERSION}}` | the version string from the upstream source (for etcd: `Version` in `_upstream/api/version/version.go`); if there is no obvious version file, leave `{{VERSION}}` |
   | `{{SCRIPT}}` | `script`, else leave `{{SCRIPT}}` |
   | `{{SCRIPT_DESCRIPTION}}` | a short description of what `script` does (read its header or body), else leave `{{SCRIPT_DESCRIPTION}}` |
   | `{{PATCHES}}` | every file in `<tool>/_patches/`, as `` [`<name without .patch>`](_patches/<file>) ``, comma-separated; `none` if the folder is empty or missing |

5. **Write** `<tool>/<slug>.md`. Do not create the diagram image — the user pastes it into `_assets/<slug>.png` from Neovim.

6. **Report** the file path and any placeholders left unfilled.

## Rules

- Never stage or commit the new file.
- Keep the template's structure and order; do not add sections or prose.
