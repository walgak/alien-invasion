# Player fighter

`player-fighter.png` is a transparent 1254 × 1254 sprite created with the built-in image-generation tool from the player's supplied silver/navy/blue fighter concept sheet. Its nose faces up. The source sheet was used as a visual reference; its labels are not game text.

The PNG is kept at source resolution with mipmaps for clean phone-scale rendering. `ship_artwork.gd` defines its visual dimensions, engine sockets and firing hardpoints. `fighter_hull.gdshader` retracts unused wing cannons and subtly animates the blue fittings. The destruction animation maps this same texture onto bounded triangular fragments. The game remains 2D.

The engine effect is a procedural, filled plasma shader attached to those sockets: blue for the player, violet for aliens. Gravity changes only its visual intensity. Plumes grow near a black hole and weaken near a white hole. Neither the new hull nor the engine effect changes hitboxes, firing intervals or projectile speeds.

## Final generation prompt (built-in mode)

Use case: background-extraction
Asset type: high-detail transparent 2D game sprite.
Input image: exact spacecraft design reference and extraction target. Use ONLY the large TOP VIEW ship on the LEFT.
Primary request: recreate that same silver, navy and electric blue fighter as an isolated, perfectly top-down game sprite, rotated 180 degrees so its sharp nose faces straight UP and its twin rear engines are at the BOTTOM. Preserve its exact distinctive silhouette, broad swept wings, angular silver alloy plate armor, navy panel insets, elongated glossy dark glass cockpit, blue luminous wing trim, intricate vents, twin cylindrical rear engines and two underslung cannon barrels. Match the original closely, not a simplified redesign.
Composition: one ship centered in a square image, with entire ship including wing tips, nose and rear fins visible and 8 percent empty margin around all sides. Fully orthographic top-down, symmetrical silhouette with crisp readable bright silver hull.
Materials: convincing metallic reflections, fine panel seams, bevels and mechanical layering baked into the 2D artwork. Blue luminous engine mouths but NO exhaust plumes: exhaust is animated separately in the game. No external fog or glow blob.
Background: genuinely transparent alpha, including gaps between wings and fuselage. No shadow plane, no checkerboard, no space background, no sheet border, no diagrams, no other views, no labels or extra text. Preserve the blue and silver design from the reference.

## Alien fighter

`alien-fighter.png` is a transparent 1254 × 1254 sprite created using the built-in image-generation tool from the supplied black/violet alien concept sheet. The [exact final prompt](alien-fighter.prompt.txt) is stored beside the asset. Nose points down, matching enemy flight; beveled graphite armor, violet conduits and metal reflections are baked into the texture.

`alien_artwork.gd` derives the alien dimensions from `ship_artwork.gd`: an 88-unit base player hull divided by 1.2 gives a 73.333-unit alien hull. Thus the player is 20% larger in linear drawing dimensions. Existing player upgrades still expand the player hull. Source images have closely matched transparent margins; collision radii and enemy health are unchanged.

All regular aliens, boss guards and carrier summons share this sprite. Violet plumes attach to the rear engine mouths. Ordinary fire alternates between the two visible wing cannons without adding shots or changing the fire interval; the escape attack uses the rear spine's gravity-cannon tip. Mipmaps preserve the fine armor details at phone scale.
