---
description: Extract questions asked since the last checkpoint and write them to a dated file. Updates the checkpoint after extraction.
---

You are extracting questions from this conversation to maintain a running log.

## Configuration

This skill accepts optional arguments: `/extract-questions [checkpoint=<path>] [outdir=<path>]`

| Argument | Default | Description |
|---|---|---|
| `checkpoint` | `~/.claude/projects/<current-project-slug>/memory/project_questions_checkpoint.md` | Path to the checkpoint memory file |
| `outdir` | `<project-root>/toy/questions/` | Directory where per-checkpoint question files are written |

If no arguments are provided, use the defaults. The `<current-project-slug>` is derived from the current working directory (replace `/` with `-`, strip leading `-`).

## Steps

1. **Resolve configuration.**
   - Parse any arguments passed to the skill.
   - Apply defaults for any unspecified arguments.

2. **Find the last checkpoint.**
   - Read the checkpoint file at the resolved `checkpoint` path.
   - Note: the checkpoint number (N), the checkpoint date, and the `outdir` if previously stored there.
   - If the checkpoint file does not exist, this is the first run: checkpoint number = 1, checkpoint date = beginning of conversation.

3. **Determine the output file.**
   - File name format: `<outdir>/YYYY-MM-DD-checkpoint-N.md`
   - Use today's date and the next checkpoint number (previous N + 1, or 1 on first run).
   - Example: `toy/questions/2026-07-11-checkpoint-1.md`
   - Files sort naturally by date prefix — one file per checkpoint.

4. **Extract questions and elaboration requests from the conversation since the last checkpoint.**
   - Scan only messages AFTER the last checkpoint date (or all messages on first run).
   - Include the user's exact wording, including any code snippets attached to the question.
   - Include every distinct question, even if asked inline with others (multi-part messages = multiple questions).
   - Also include explicit elaboration requests: messages starting with "elaborate on", "can you elaborate", "tell me more about", "explain X in more detail", etc.
   - Do NOT include questions the assistant asked the user.
   - Do NOT include questions already captured in a previous checkpoint file.
   - If a question or elaboration request was made multiple times since the last checkpoint, include it once.

5. **Write the output file.**
   Create `<outdir>/YYYY-MM-DD-checkpoint-N.md` with this structure:
   ```
   # Questions — Checkpoint N (YYYY-MM-DD)

   _Extracted from conversation since: <last checkpoint date or "beginning">_

   ---

   ## <Topic>

   - <question>
   - <question with snippet>:
     ```
     <code snippet>
     ```

   ## <Topic>

   - ...
   ```
   Group questions by topic. Add new topic sections as needed.

6. **Update the checkpoint file.**
   Overwrite the checkpoint file with:
   ```
   ---
   name: questions-checkpoint
   description: Tracks checkpoint for question extraction. Next extraction starts after <today's date>.
   metadata:
     type: project
   ---

   Checkpoint <N> set on <today's date>.

   Last output file: <path to file just written>
   Checkpoint number: <N>
   Outdir: <resolved outdir>

   **How to apply:** When user asks to extract questions, read this file, note the checkpoint date,
   and only extract questions from conversation messages after that date.
   ```

7. **Report** to the user:
   - How many questions were extracted
   - The output file path
   - The new checkpoint date

## Rules

- Preserve the user's exact wording — do not paraphrase.
- Group questions by topic (Raft, WAL, BoltDB, gRPC, Go Runtime, etc.).
- If a message contains both a question and a statement, extract only the question part.
- Code snippets that are part of a question should be included inline under the question.
- The output directory must be created if it does not exist.
