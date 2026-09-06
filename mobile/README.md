# Alien Invasion — First Contact

A playable Godot prototype developed from the original Python/Pygame game, including endless flight and the creator's four boss concepts. Tested with Godot 4.7.2 on macOS.

## Play

On this Mac, double-click `Play.command`. Alternatively, import `project.godot` in Godot and press **F5**. No Python packages or third-party Godot plugins are needed.

Select **Launch endless flight**. Random alien groups and asteroids arrive regularly. About 45% of regular aliens zigzag; alien shot intervals are 1.05–1.9 seconds. Boss music announces an approaching boss after roughly 40–55 seconds of ordinary flight; victories continue the run with a short recovery. All four bosses appear once per shuffled set:


| Flight | Objective |
| --- | --- |
| Black hole | Shoot the boss. It fires a fast rift cannon that detonates into a black hole. Tap rapidly to neutralise the pull. |
| White hole | Shoot the boss. It fires a fast rift cannon that detonates into a white hole. Tap rapidly to neutralise the push before reaching an edge. |
| Swarm carrier | Dodge or shoot alien ships pulled from offscreen, tethered to the boss and thrown toward you. |
| Asteroid forge | Shoot the boss as it pulls rocks from offscreen on attached space-fold strands, then slings them toward the ship. Small, medium, and large rocks take 3, 6, and 10 shots. |

Every boss fight repeats the same cycle: exchange fire and dodge the boss's aimed volleys, face its signature special attack, then return to the firefight. A new special is scheduled after a random 5–9 seconds of normal fighting. Surviving a special does not damage the boss or end the battle. Only player bullets hitting its core reduce its health; reaching zero wins the fight and resumes endless flight. Boss health increases as more bosses are defeated.

Black-hole and white-hole attacks begin with a rift cannon fired five times faster than normal boss bullets. The cannon folds space as it travels, then explodes with an original high-to-low sci-fi blast and creates the hole. The hole stays active for four seconds of tapping. The asteroid boss warns, then pulls a finite barrage of rocks from offscreen using space-fold strands anchored to its body. Each rock pulls inward, pauses for a brief wind-up, and is slung toward the ship's position at release as its strands fade. The boss waits for the rocks to be dodged or destroyed before resuming normal shots. Damage already dealt to the boss persists between cycles.

**Touch:** drag horizontally to steer and dodge normal shots. During an active hole attack, lift your finger and tap repeatedly anywhere in the playfield. Steering returns after the hole closes. Old hostile bullets clear when tapping starts so they cannot hit you while steering is unavailable. Weapons always fire automatically, including during special attacks.

Each tap fully cancels the hole's force for a brief beat. Keep tapping to hold the current position exactly. Tapping never pushes the ship away and never recovers ground lost; when the tap window expires, the pull or push resumes at full strength. The force meter shows whether neutralisation is active.

Both gravity holes form in the lower-middle region (28–72% screen width, 57–70% screen height). Cannons aim at a fixed point rather than tracking the ship. A clearance check redirects an unsafe landing before the core opens. White holes push away from their core, usually downward. Any of the four edges can destroy the ship, and vertical displacement persists between special attacks. Defeating the gravity boss restores the normal ship position.

**Mouse:** click and drag to steer; click repeatedly to neutralise a hole.

**Keyboard:** arrow keys or A/D to steer; press Space repeatedly to neutralise a hole. P/Esc pauses and resumes. Enter launches a flight. Holding Space does not count as repeated taps.

Pause also activates when the application loses focus. The endless high score saves locally and persists between runs. Sound can be toggled on the title or pause screen. There are no accounts, advertisements, analytics, or network requests in the game.

## Prototype scope

This is a desktop-playable project with mobile input and a portrait layout. It is not an App Store/Google Play release or a signed phone installation. Physical-device touch feel, cutouts, interruptions, audio behavior, battery use, and difficulty still need to be tested. Android SDK/export templates and signing are not configured in this project. iOS export requires Xcode, Godot export templates, and signing.

Random enemies drop weapon upgrades and life pickups. Basic upgrades have a 6% chance (30-kill fallback); advanced upgrades have a 1.5% chance with at most one laser/rocket upgrade drop per boss interval. Life drops have a 6% chance. Weapons progress from single to double, triple, piercing laser, and explosive rockets. Hull lives cap at three. Upgrades collectively supply one emergency life on lethal damage: weapons reset to single with one hull life remaining. Ordinary damage preserves the upgrade. Bosses use the same rare drop rules as regular enemies. Surplus drops at maximum capacity score bonus points.

Final art, difficulty balancing, and phone export remain future work. Hole attacks temporarily replace dragging with tapping; that control switch and the tapping intensity are the main things to playtest. The tap rate and attack timing are tunable in `scripts/boss.gd`.

## Code guide

- `game.gd`: run state, input, scoring, spawning, collisions, and app lifecycle.
- `ship.gd`, `enemy.gd`, `projectile.gd`: arcade actors and summoned alien motion.
- `weapon_system.gd`, `pickup.gd`: weapon patterns, upgrade levels, and collectible drops.
- `boss.gd`, `asteroid.gd`: the four boss mechanics and destructible rocks.
- `space_background.gd`, `space_folds.gd`, `shaders/`: layered procedural sky and background refraction. One screen-reading pass combines up to eight object lenses and six strands; actors and HUD render above it. Animation uses game time so pausing also freezes the folds.
- `interface.gd`: menus, HUD, and attack instructions.
- `progress.gd`: best scores and sound preference in a local ConfigFile.
- `sound.gd`: original, synthesized effects and looping boss music generated in memory, including the rift cannon pitch drop.

All new artwork is drawn with Godot primitives; the icon is an original SVG. No artwork or recordings from the Python game are bundled here. Godot's bundled font is used. This document does not change the original repository's licensing.

## Verification

The headless checks cover run reset, three-life semantics, save/load, swept projectile collisions, steering, pause, touch ownership, both hole failure/survival paths, asteroid damage/destruction, weapon upgrades, emergency lives, and endless records. A second check sends events through Godot's GUI/input pipeline. Rendering captures use Godot's actual desktop renderer, including cannon frames and matching hole/asteroid frames with refraction disabled for comparison. Headless checks validate shader syntax but cannot verify GPU output.

From this directory, use a temporary save path ending in `smoke-record.cfg`:

```sh
ALIEN_SAVE_PATH=/tmp/alien-smoke-record.cfg godot --headless --path . --script tests/smoke.gd
ALIEN_SAVE_PATH=/tmp/alien-input-record.cfg godot --headless --path . --script tests/input_flow.gd
ALIEN_SAVE_PATH=/tmp/alien-boss-cycle-record.cfg godot --headless --path . --script tests/boss_cycle.gd
ALIEN_SAVE_PATH=/tmp/alien-hole-physics-record.cfg godot --headless --path . --script tests/hole_physics.gd
ALIEN_SAVE_PATH=/tmp/alien-endless-record.cfg godot --headless --path . --script tests/endless.gd
```

To capture screens, set `ALIEN_CAPTURE_DIR` to an existing output directory and run `tests/capture.gd` with a graphical display. The save override keeps test scores separate from your real records.
