# Player fighter

`player-fighter.png` is a transparent 1254 × 1254 sprite created with the built-in image-generation tool from the player's supplied silver/navy/blue fighter concept sheet. Its nose faces up. The source sheet was used as a visual reference; its labels are not game text.

The PNG is kept at source resolution with mipmaps for clean phone-scale rendering. `ship_artwork.gd` defines its visual dimensions, engine sockets and firing hardpoints. `fighter_hull.gdshader` retracts unused wing cannons and subtly animates the blue fittings. The destruction animation maps this same texture onto bounded triangular fragments. The game remains 2D.

The engine effect is a procedural, filled plasma shader attached to those sockets: blue for the player, violet for aliens. Gravity changes only its visual intensity. Plumes grow near a black hole and weaken near a white hole. Neither the new hull nor the engine effect changes hitboxes, firing intervals or projectile speeds.

## Final generation prompt (built-in mode)

undefined
