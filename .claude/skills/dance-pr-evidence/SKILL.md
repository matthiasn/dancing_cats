---
name: dance-pr-evidence
description: "Standard for how character-animation PRs present visual evidence: before/after render grids, true-speed GIFs, movement-curve comparisons, and panel scorecards embedded directly in the PR body/comments. Use whenever opening or commenting on a PR that touches a dance clip, a rendering pass, the blend/transition machinery, or any shared runtime mechanism affecting the rig."
---

# Dance PR Evidence

Every PR that changes character animation must let a reviewer judge the
change from the PR page alone — no local repro required. This is a hard
requirement, not a nice-to-have (owner, 2026-07-03/07-05): images and GIFs
go in the PR description/comments as embedded markdown, never only as a
link to an external Artifact page.

## What every animation PR needs

1. **Root cause + fix, in prose** — the same reasoning that would go in
   the commit message, repeated in the PR body so a reviewer never has to
   open a terminal.
2. **Before/after render images** — see `dance-render-artifacts` for how
   to generate the grids/sheets. Render "after" from the current branch;
   render "before" from a git worktree at the PR's merge-base for just
   the touched files, then restore the branch's files.
3. **Before/after loop GIFs**, true playback speed (see
   `dance-render-artifacts` for the 50fps GIF-format ceiling and the
   dense-sequence recipe). Label which is which.
4. **Movement-curve (motion-trace) evidence** for any claim of "more/less
   X" — a before/after crop of the relevant channel with the printed
   range/events-per-second numbers, not just "looks better."
5. **Panel scores**, when a review panel ran — a compact table (lens x
   clip/handoff, min score bolded) plus the verdict's most load-bearing
   sentence, posted as a PR comment once the panel completes (panels are
   often still running when the PR opens).

## Building the PR body

- **Host rendered assets in the separate `matthiasn/dancing_cats-docs` repo
  as PNG — do NOT commit them into this code repo** (owner, 2026-07-07: keep
  the code repo lean; webp had rendering issues, so use PNG). Clone at
  `/home/parallels/github/dancing_cats-docs`, drop images under
  `images/reviews/`, commit + push to its `main`, then reference them by
  `https://raw.githubusercontent.com/matthiasn/dancing_cats-docs/main/images/reviews/<name>.png`.
  Because they live on that repo's `main` (not a feature branch here), the
  URLs are permanent and survive branch deletion — `--delete-branch` on merge
  is fine. Use descriptive, move-scoped basenames
  (e.g. `buga_weightcommit_after_grid.png`).
- Downscale is optional (separate repo), but keep grids reasonable.
- Reference them with standard markdown `![alt](url)` in
  `gh pr create --body-file <file>` (write the body to a scratch file
  first — heredocs with `$(...)` inside markdown tables get mangled by
  the shell).
- If the panel hasn't run yet when the PR opens, say so explicitly
  ("Panel round N running; scores will be posted as a comment") rather
  than leaving the reader to wonder.

## Example structure (adapt headers to the actual change)

```markdown
## <title> — <one-line root cause/fix summary>

### Changes
1. <item> — <root cause, what changed, how verified>
2. ...

### <Channel> before/after
![before/after](<raw-githubusercontent-url>)

### Loop GIFs (true playback speed)
| Clip | Before | After |
|---|---|---|
| <clip> | ![](...) | ![](...) |

### Panel round N (4 lenses)
| Clip | animator | rigging | mocap | coach | min |
|---|---|---|---|---|---|
| ... |

### Verification
- Full suite green (N tests), full-repo analyze clean.
- <specific measured deltas, not just "looks better">
```

## After opening

- Post panel results as a `gh pr comment` once the workflow completes,
  using the same table format.
- Also send the GIFs to the owner directly (SendUserFile) when
  presenting a round — the PR link alone is easy to miss.
- When a round only partially lands, say so in the comment (which lenses
  agreed, which held back, and why) rather than only reporting the mean.

## See Also

- `dance-render-artifacts` for how to generate every asset referenced here.
- `character-motion-review-panel` for running the panel itself.
