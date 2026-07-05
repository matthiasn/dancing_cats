# Character / Dance — Architecture Decision Records

A **self-contained** ADR series for the `character` feature (the chibi-cat rig,
the dance-to-track demo, the camera director, and the choreography encoding).

This series is **deliberately separate** from the repository-wide `docs/adr/`
index and is numbered from `0001` with a `CHAR-` prefix. The character/dance
subsystem is expected to be extracted into its own package; keeping its decision
records beside the code means they travel with it. **Do not merge this series into
the Lotti ADR index, and do not renumber it to continue that sequence.**

## File naming

- `CHAR-NNNN-short-title.md` — `NNNN` zero-padded, increasing within *this*
  series only.

## Template

Each ADR contains: `Status`, `Date`, `Context`, `Decision`, `Consequences`,
`Related` (optional).

## Index

- [`CHAR-0001-dance-choreography-encoding-and-move-library.md`](./CHAR-0001-dance-choreography-encoding-and-move-library.md)
  — **Accepted/implemented.** How dance dynamics are encoded (the Laban-Effort
  layer over keyframed accents), the move-library/notation-as-score model, and
  which Afrobeats moves the catalog encodes (and which were dropped, and why).
  Its **Implementation outcome** section records the as-built reality: all six
  moves shipped and panel-certified ≥9.0/10, authored as separate hand-keyed
  clips (a deliberate divergence from the planned `AfrobeatsMove`-compilation),
  plus the reusable engine toolkit that grind produced (`danceHeadBobScale`,
  `supportFootWorldAnchor`, `easeOutBack` IK overshoot, the forearm sleeve band)
  and the keyframe-sampling constraint that shaped it.
- [`CHAR-0002-angular-motion-diagnostics-and-overshoot-settle.md`](./CHAR-0002-angular-motion-diagnostics-and-overshoot-settle.md)
  — **Accepted/implemented.** Two independent mechanisms: a CI-only test gate
  on world-space angular velocity/acceleration (tempo-scaled by
  `kDanceRealTempoSpeedup`), and an always-on runtime pass
  (`overshoot-settle`) that injects a critically-damped rotational settle
  after a hard authored stop. Also documents the two-bone-IK
  near-degenerate-reach artifact that tripped the gate and how it was
  actually fixed (choreography reach, not engine code).
- [`CHAR-0003-effort-dynamics-split-clock.md`](./CHAR-0003-effort-dynamics-split-clock.md)
  — **Accepted/implemented.** Wires CHAR-0001's dormant `DanceDynamics` layer
  into the live trio via a beat-local time warp applied to upper-body
  channels only (feet/legs/root stay on the shared clock, so the trio's
  per-member zero-time-offset invariant holds by construction). Composes
  `effective = clamp(moveBase + budgetCap(catProfile + sectionEnergy))` per
  cat per moment. Landed in two passes: plumbing as a provable no-op, then
  tuning (the real D4 Effort table, lane personalities, section-energy gain,
  and a live warp gain raised from `0.35` to `0.5` after a 4-lens motion
  panel found the differentiation too subtle at the initial value) with a
  new kinematic gate proving the headline support-bone-exact invariant on
  the real catalog.

## Related research

Background fan-outs preserved under [`../research/`](../research/):

- `2026-06-27-movement-notation-synthesis.md` — movement-notation, Laban Effort,
  animation-principle, and polyrhythm synthesis.
- `2026-06-28-afrobeats-dance-moves.md` — per-move, count-accurate keying notes
  with side-on feasibility flags and sources.
