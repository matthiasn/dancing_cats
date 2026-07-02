# Afrobeats Choreography Authenticity Audit (2026-07-02)

Web-researched audit of the five catalogue moves against real Afrobeats
practice, cross-checked against our own research doc
(`2026-06-28-afrobeats-dance-moves.md`) and the shipped clip data in
`cat_in_suit.dart`. Headline: the research doc is largely accurate; the big
authenticity gaps are three places where the IMPLEMENTATION deviates from its
own research — plus one doc error (Zanku's default carriage).

## Ranked findings

1. **Buga hit shape (HIGH).** Implemented: ONE arm thrusts overhead while the
   other drops — an asymmetric "ta-da". Documented reality: on "Buga o" BOTH
   arms bow outward at the sides like a proud peacock, shoulders puffed,
   chest open — the gesture everyone imitated in 2022. The dips/rise engine
   ("go low low low" progressive sink, leg-driven rise, chest pop) is
   count-accurate and should not change. Fix: two mirrored "peacock bow" hand
   targets (x ±78, y −30..−40, elbows bowed outboard) and BOTH clavicle/
   socket shrug key sets firing on every hit. Doc fix: the research doc
   states the one-arm thrust as fact (L100–104) — correct it.
2. **Shaku crossed-X duty cycle inverted (HIGH).** The crossed-wrist X
   ("handcuffed") is the HELD base posture in the real dance, opened only
   for freestyle punctuation. We hold the OPEN pose and flash the cross for
   1–2 frames per beat. Fix: crossed pose on held keys (x ∓10–15 across
   centre, y ≈ −55, tension 1), open scoop as the transient easeOutBack hit.
   Also: supports change once per bar — the real engine is a staggered
   half-gallop; split DanceSupportSpans to 8 frames and add a harmonic-4
   skip bob. The dab accent is era-plausible but a "generator pull" is the
   native freestyle in that slot.
3. **Azonto mime vocabulary missing (HIGH).** The defining feature — mimed
   everyday actions (steering, jab, ironing, phone) with hands pointing DOWN
   in flowing circles between quotes — is reduced to straight-arm horizontal
   point-outs (the "generic boy band" smell our SKILL.md warns about). The
   side-readable mime subset is already catalogued in our research doc and
   unused. Also missing: ball-of-foot pivot on the free foot (planted-stiff/
   pivoting-free asymmetry), off-beat hip pop, head-turn + smirk. Contact
   spans contradict their own comment (per-beat alternation vs "planted foot
   holds").
4. **Zanku gbese kick + attitude (MED-HIGH).** Stamp cadence, tap-dig-scrape
   texture, rib-guard fists, and the FORWARD carriage are right (the code is
   more correct than our research doc here — see doc fixes). But the
   style's namesake air-kick is shin-height (should peak far higher, with a
   lean-back only at the kick peak), the chin-down "look at the floor" head
   is absent, and the sources' "vigorous shoulder rolls" have no channel.
5. **Sekem anchors dropped (MED).** Our research doc declared "hand pose +
   foot twist" the non-negotiable authenticity anchors; the implementation
   has neither (own-side paddles instead of one-hand-on-chest/one-on-back;
   stomps with no plant twist). Fix: pin lead paw at the sternum, off paw at
   the back-waist (side-swap once per bar), foot-twist keys on the plants,
   contralateral clavicle pump.
6. **Global: dead heads / no shoulder isolation layer (MED, cross-cutting).**
   danceHeadBobScale 0.2–0.3 and face-cam locking delete the attitude layer
   (Zanku chin-down, Azonto head-turn, Sekem nod); dedicated shoulder work
   exists only in buga. The grounded lower body is authentically strong —
   the upper body carries the remaining inauthenticity.

## Doc/comment corrections

- `2026-06-28-afrobeats-dance-moves.md` L29/33: Zanku "torso leaned back
  10–20°" is wrong as the DEFAULT carriage — sources describe a bent-forward
  back with dropped chin; the lean-back is only true at the kick peak.
- Same doc L100–104: Buga one-arm thrust → both-arm peacock bow (or flag as
  stylization like the Sekem entry does).
- `cat_in_suit.dart` "hit-and-hold square wave" comment on the shaku X
  misdescribes the data (the hold is on the open pose).
- Azonto contact-span comment contradicts the spans beneath it.

## What we verifiably got right

On-beat sink into the pocket (rootDy bottoms on counts, pocketScaleY),
hips-lead-chest-answers micro-timing, per-beat alternating zanku stamps with
a genuine support map, buga's progressive three-dip sink and leg-driven
rise, sekem's dwelling lateral weight (no pass-through-centre sine),
anti-clone ensemble variance, crossed WRISTS not folded forearms.

Key sources: Guardian NG & Legit.ng & Face2Face Africa (Shaku), Filter Free
NG & How-To-9ja & NativeMag (Zanku), Wikipedia & AFAR & GhanaRemembers
(Azonto), Wikipedia & Skabash & the official dance class video (Buga),
NativeMag & OkayAfrica (Sekem), Red Bull & Divira & District234 (grammar).
Full URLs in the audit transcript.
