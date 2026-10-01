# Final boss artwork

The three 1254 × 1254 transparent PNGs were created with the built-in image-generation tool from the player's supplied boss concept sheets. Labels and illustrated attack examples on those sheets are visual references, not new game instructions. The later white/blue white-hole sheet is the primary white-hole design.

- `black-hole.png`: graphite/silver jagged armor, floating violet scythes, black singularity.
- `white-hole.png`: ivory/silver segmented armor, blue conduits, gold seams, white reactor.
- `asteroid-forge.png`: basalt boulder armor over orange-lit mechanical couplings.

The full generation prompts are in [generation-prompts.md](generation-prompts.md). Original generated alpha is preserved. Mipmaps keep the fine details clean at phone resolution.

`boss_artwork.gd` renders each hull at 272 logical pixels, roughly three times the base player's 88-pixel artwork. A bounded 16 × 16 2D mesh allows gentle movement of the outer pieces; a canvas shader adds flowing core light, a subtle moving reflection, damage scars and impact flashes. Smoke appears below 36% health. These are pre-rendered sprites with cosmetic 2D effects, not 3D actors.

`boss.gd` centralizes damage, shield, guard-orbit and dodge radii. The entire Boss node must never be scaled: its traveling cannon and active hole coordinates are already in arena space. Attack timing, health progression and launched-hole physics are unchanged. The alien-throwing carrier was removed from the roster; ordinary alien swarms and boss guards remain.
