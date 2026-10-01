# Supplied boss destruction sheets

These are the user's unmodified 2172 × 724 PNGs, provided on October 1, 2026:

- `black-collapse.png`: `ChatGPT Image Oct 1, 2026 at 04_37_19 PM-1.png` — armor spirals into a purple singularity.
- `white-burst.png`: `ChatGPT Image Oct 1, 2026 at 04_37_21 PM-2.png` — reactor flashes and blue/white fragments expand.
- `asteroid-shatter.png`: `ChatGPT Image Oct 1, 2026 at 04_37_22 PM-3.png` — molten armor cracks, ignites, and scatters.

Each sheet has eight unequally spaced frames on an opaque black background. `boss_collapse.gd` contains their pixel bounds and reactor pivots; `boss_destruction.gdshader` samples and crossfades two frames, removes the black background, and preserves the black boss's opaque central horizon. The artwork is not regenerated or destructively cut. Runtime correction restores the intact frames to the live boss's roughly 272-pixel square footprint.

The original hull dissolves into the authored animation over 0.15 seconds. Black reaches the inward-collapse phase at 0.65 seconds; white and asteroid reach the explosion phase then. All three leave a fading debris/energy tail until 1.45 seconds. Only black and white open the existing eight-second death well at 0.65 seconds. Existing launched attacks continue separately. No new attacks or gameplay effects are inferred from the concept sheets.

Keep these texture imports lossless, unfiltered at import, and without mipmaps: manual sampling at the fitted gameplay size uses linear filtering and isolated frame bounds, so adjacent artwork cannot bleed into another frame.
