# Alien Invasion — First Contact

A playable Godot prototype developed from the original Python/Pygame game, including the creator's three boss concepts. Tested with Godot 4.7.2 on macOS.

## Play

On this Mac, double-click `Play.command`. Alternatively, import `project.godot` in Godot and press **F5**. No Python packages or third-party Godot plugins are needed.

Choose a flight on the title screen, then **Launch mission**:

| Flight | Objective |
| --- | --- |
| First contact | Clear the 15-ship fleet with three lives. |
| Black hole | Shoot the boss. When its hole opens next to your ship, tap rapidly to resist the pull. Entering the dark core ends the run. |
| White hole | Shoot the boss. Tap rapidly to resist the push. Hitting a screen boundary during the attack destroys the ship and ends the run. |
| Asteroid forge | Shoot the boss while dodging its asteroids. Two shots break an asteroid; a collision costs one life. |

Every boss fight repeats the same cycle: exchange fire and dodge the boss's aimed volleys, face its signature special attack, then return to the firefight. A new special is scheduled after a random 5–9 seconds of normal fighting. Surviving a special does not damage the boss or end the battle. Only player bullets hitting its core reduce its health; reaching zero wins the fight.

Black-hole and white-hole attacks have a 1.25-second warning followed by four seconds of tapping. The asteroid boss warns, throws a finite barrage, and waits for the rocks to be dodged or destroyed before resuming normal shots. Damage already dealt to the boss persists between cycles.

**Touch:** drag horizontally to steer and dodge normal shots. During an active hole attack, lift your finger and tap repeatedly anywhere in the playfield. Steering returns after the hole closes. Old hostile bullets clear when tapping starts so they cannot hit you while steering is unavailable. Weapons always fire automatically, including during special attacks.

**Mouse:** click and drag to steer; click repeatedly to resist a hole.

**Keyboard:** arrow keys or A/D to steer; press Space repeatedly to resist a hole. P/Esc pauses and resumes. Enter launches a flight. Holding Space does not count as repeated taps.

Pause also activates when the application loses focus. Each flight has its own saved best score. Sound can be toggled on the title or pause screen. There are no accounts, advertisements, analytics, or network requests in the game.

## Prototype scope

This is a desktop-playable project with mobile input and a portrait layout. It is not an App Store/Google Play release or a signed phone installation. Physical-device touch feel, cutouts, interruptions, audio behavior, battery use, and difficulty still need to be tested. Android SDK/export templates and signing are not configured in this project. iOS export requires Xcode, Godot export templates, and signing.

The four encounters are independently selectable so their mechanics can be evaluated. A campaign, boss sequence, upgrades, music, and final art remain future work. Hole attacks temporarily replace dragging with tapping; that control switch and the tapping intensity are the main things to playtest. The tap rate and attack timing are tunable in `scripts/boss.gd`.

## Code guide

- `game.gd`: run state, input, scoring, spawning, collisions, and app lifecycle.
- `ship.gd`, `enemy.gd`, `projectile.gd`: the basic arcade actors.
- `boss.gd`, `asteroid.gd`: the three boss mechanics and destructible rocks.
- `interface.gd`: menus, mission selector, HUD, and attack instructions.
- `progress.gd`: best scores and sound preference in a local ConfigFile.
- `sound.gd`: original, synthesized effects generated in memory.

All new artwork is drawn with Godot primitives; the icon is an original SVG. No artwork or recordings from the Python game are bundled here. Godot's bundled font is used. This document does not change the original repository's licensing.

## Verification

The headless checks cover run reset, three-life semantics, save/load, swept projectile collisions, steering, pause, touch ownership, both hole failure/survival paths, asteroid damage/destruction, and separate flight records. A second check sends events through Godot's GUI/input pipeline. Rendering captures use Godot's actual desktop renderer.

From this directory, use a temporary save path ending in `smoke-record.cfg`:

```sh
ALIEN_SAVE_PATH=/tmp/alien-smoke-record.cfg godot --headless --path . --script tests/smoke.gd
ALIEN_SAVE_PATH=/tmp/alien-input-record.cfg godot --headless --path . --script tests/input_flow.gd
ALIEN_SAVE_PATH=/tmp/alien-boss-cycle-record.cfg godot --headless --path . --script tests/boss_cycle.gd
```

To capture screens, set `ALIEN_CAPTURE_DIR` to an existing output directory and run `tests/capture.gd` with a graphical display. The save override keeps test scores separate from your real records.
