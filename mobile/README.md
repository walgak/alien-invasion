# Alien Invasion — First Contact

A playable Godot prototype developed from the original Python/Pygame game, including endless flight and the creator's four boss concepts. Tested with Godot 4.7.2 on macOS.

## Play

On this Mac, double-click `Play.command`. Alternatively, import `project.godot` in Godot and press **F5**. No Python packages or third-party Godot plugins are needed.

Select **Launch endless flight**. Random alien groups and asteroids arrive regularly. About 45% of regular aliens zigzag; alien firing uses a 1.05–1.9-second reference divided by the current difficulty scale. Boss music announces an approaching boss after roughly 40–55 seconds of ordinary flight; victories continue the run with a short recovery. All four bosses appear once per shuffled set:


| Flight | Objective |
| --- | --- |
| Black hole | Shoot the boss. It fires a fast rift cannon that detonates into a black hole. Tap rapidly to neutralise the pull. |
| White hole | Shoot the boss. It fires a fast rift cannon that detonates into a white hole. Tap rapidly to neutralise the push before reaching an edge. |
| Swarm carrier | Dodge or shoot alien ships pulled from offscreen, tethered to the boss and thrown toward you. |
| Asteroid forge | Shoot the boss as it pulls rocks from offscreen on attached space-fold strands, then slings them toward the ship. Small, medium, and large rocks take 5, 8, and 12 shots initially. |

Every boss fight repeats the same cycle: exchange fire and dodge the boss's aimed volleys, face its signature special attack, then return to the firefight. A new special is scheduled after a random 5–9 seconds of normal fighting. Surviving a special does not damage the boss or end the battle. Player weapons and redirected asteroids reduce its health after the alien guards are destroyed; reaching zero wins the fight and resumes endless flight. Boss health increases as more bosses are defeated.

Black-hole and white-hole attacks begin with a rift cannon fired five times faster than normal boss bullets. The cannon folds space as it travels, then explodes with an original high-to-low sci-fi blast and creates the hole. The hole stays active for four seconds of tapping. The asteroid boss warns, then pulls a finite barrage of rocks from offscreen using space-fold strands anchored to its body. Each rock pulls inward, pauses for a brief wind-up, and is slung toward the ship's position at release as its strands fade. The boss waits for the rocks to be dodged or destroyed before resuming normal shots. Damage already dealt to the boss persists between cycles.

**Touch:** hold and drag in the lower flight area to steer and fire; lifting the finger leaves the ship idle. During an unshielded hole attack, lift your finger and tap repeatedly anywhere in the playfield. A shield preserves steering and firing during gravity. The automatic hazard ward deflects incoming threats while steering is unavailable.

Each tap fully cancels the hole's force for a brief beat. Keep tapping to hold the current position exactly. Tapping never pushes the ship away and never recovers ground lost; when the tap window expires, the pull or push resumes at full strength. The force meter shows whether neutralisation is active.

Both gravity holes form in the lower-middle region (28–72% screen width, 57–70% screen height). Cannons aim at a fixed point rather than tracking the ship. A clearance check redirects an unsafe landing before the core opens. White holes push away from their core, usually downward. Any of the four edges can destroy the ship, and surviving each attack schedules a smooth return to cruising height without resetting horizontal position.

**Mouse:** click and drag to steer; click repeatedly to neutralise a hole.

**Keyboard:** arrow keys or A/D to steer; press Space repeatedly to neutralise a hole. P/Esc pauses and resumes. Enter launches a flight. Holding Space does not count as repeated taps.

Pause also activates when the application loses focus. The endless high score saves locally and persists between runs. The title and pause screens have saved controls for sound, vibration, screen shake, laser brightness, and gravity distortion. There are no accounts, advertisements, analytics, or network requests in the game.

## Prototype scope

This is a desktop-playable project with mobile input and a portrait layout. It is not an App Store/Google Play release but supports a signed iPhone development installation. Physical-device touch feel, cutouts, interruptions, audio behavior, battery use, and difficulty still need to be tested. Android signing is not configured. The iOS preset exports an Xcode project for development signing with the configured Apple team.

### Special weapons

- **Gravity:** eligible alien kills charge the button: 10 kills unlock the smallest hole and 50 fill it. Press the button, tap a safe destination, then lift. A one-third-second muzzle-charge animation plays before launch. A single hole lasts **3–7.5 seconds**; stored charge changes size and duration, never pull strength. Hole absorption and annihilation kills do not recharge it. If unshielded gravity interrupts preparation, the launch is canceled and the charge stays banked.
- **Laser:** collect up to 99 charges. Its button selects a ten-second firing budget; lifting the steering finger pauses the clock. Toggle back to the primary guns and resume the same remaining budget later. Expiry restores the previous weapon and never automatically spends another charge.
- **Cannons:** start with 30; drops add five, up to 99. Tapping an enemy fires one homing cannon. With at least five in stock, the button launches a volley at visible small aliens, prioritizing those nearest escape. It spends only the available ammunition needed for their health, accounting for cannons already in flight. Both controls share one inventory.

The primary progression is **single → double → triple → enhanced triple plasma**. All primary bullets travel at 850 units/second with a 0.17-second cadence. Normal bullets deal one damage, enhanced plasma two, and cannons three plus splash within 65 pixels. The continuous laser instantly kills small aliens, deals one boss hit per 0.25 seconds, and reflects away from the player when it touches asteroids. It also pushes asteroids, with a stronger effect on small rocks.

Hull lives have a strict maximum of three; health pickups refill them and weapon upgrades grant no backup life. Alien contact destroys the alien with an electrical discharge and costs one life. Unprotected asteroid contact and an escaped alien's homing gravity cannon are instant losses.

Forced gravity tapping automatically supplies a hazard ward that deflects bullets, rocks and colliding aliens. It does **not** protect from the gravity core or lethal white-hole boundary. A collected ten-second shield also grants gravity immunity, steering and firing, including special weapons. Shields drop at one third the hull-repair rate. Only asteroids redirected by the player’s hole, shield/ward or laser can damage enemies: small aliens die; bosses take one cannon’s damage, respecting their alien guards. Fragments retain this ownership.

Every hole closure requests smooth recovery to the normal cruising **Y** position while retaining X. Recovery waits for all overlapping gravity to end, including when a collected shield is active. Bosses recruit only aliens above the screen midpoint; lower aliens continue forward. Boss hulls stay clear of player event horizons for the entire attack, with a gravity-only distortion shield that does not change ordinary weapon damage.

Final art, difficulty balancing, and store submission remain future work. Hole attacks temporarily replace dragging with tapping; that control switch and the tapping intensity are the main things to playtest. The tap rate and attack timing are tunable in `scripts/boss.gd`.

## Code guide

- `combat_controls.gd`: independent steering/target fingers, special inventories, hazard ward and return bookkeeping.
- `death_visual.gd`, `impact_visual.gd`: textured hull failure, fire, pressure wave and pooled electrical contact effects.

- `game.gd`: run state, input, scoring, spawning, collisions, and app lifecycle.
- `ship.gd`, `enemy.gd`, `projectile.gd`: arcade actors and summoned alien motion.
- `weapon_system.gd`, `pickup.gd`: weapon patterns, upgrade levels, and collectible drops.
- `boss.gd`, `asteroid.gd`: the four boss mechanics and destructible rocks.
- `space_background.gd`, `space_folds.gd`, `shaders/`: layered procedural sky and background refraction. One screen-reading pass combines up to eight object lenses and six strands; actors and HUD render above it. Animation uses game time so pausing also freezes the folds.
- `interface.gd`: menus, HUD, and attack instructions.
- `progress.gd`: best scores and sound preference in a local ConfigFile.
- `sound.gd`: original, synthesized effects and looping flight and boss music generated in memory, including the rift cannon pitch drop.

The 2D artwork combines detailed raster sprites, procedural rocks, plasma shaders and an original SVG icon. Asset prompts and provenance are recorded alongside the committed images. Original Python artwork and outside sound recordings are not bundled into the Godot game.

## Verification

The headless checks cover run reset, three-life semantics, save/load, swept projectile collisions, steering, pause, touch ownership, both hole failure/survival paths, asteroid damage/destruction, weapon upgrades, special inventories, and endless records. A second check sends events through Godot's GUI/input pipeline. Rendering captures use Godot's actual desktop renderer, including cannon frames and matching hole/asteroid frames with refraction disabled for comparison. Headless checks validate shader syntax but cannot verify GPU output.

From this directory, use a temporary save path ending in `smoke-record.cfg`:

```sh
ALIEN_SAVE_PATH=/tmp/alien-smoke-record.cfg godot --headless --path . --script tests/smoke.gd
ALIEN_SAVE_PATH=/tmp/alien-input-record.cfg godot --headless --path . --script tests/input_flow.gd
ALIEN_SAVE_PATH=/tmp/alien-boss-cycle-record.cfg godot --headless --path . --script tests/boss_cycle.gd
ALIEN_SAVE_PATH=/tmp/alien-hole-physics-record.cfg godot --headless --path . --script tests/hole_physics.gd
ALIEN_SAVE_PATH=/tmp/alien-endless-record.cfg godot --headless --path . --script tests/endless.gd
```

To capture screens, set `ALIEN_CAPTURE_DIR` to an existing output directory and run `tests/capture.gd` with a graphical display. The save override keeps test scores separate from your real records.

Difficulty begins at 1% and rises by one point per boss defeated. It changes enemy firing frequency and drop chances, while movement, wave timing, bullet speeds, and gravity strength stay constant. Small alien ships take 3 hits initially, gaining one hit every two victories up to 9. Asteroids begin at 5/8/12 hits by size and gain one hit every two victories. Boss health follows floor(100 - 780 / (12 + victories)): 35, 40, 44, 48… with a 99-hit ceiling. The underlying curve approaches 100 without reaching it. Single/double/triple bullets all travel at 850 units/s with a 0.17-second firing interval. Rockets travel at 660 units/s; the ten-second laser instantly kills aliens, pushes asteroids and reflects away from the player, and deals one boss hit per 0.25 seconds. Original flight music switches to boss music during encounters. Planets drift through the sky and are replaced after passing offscreen.

## iPhone development build

The iOS preset uses bundle ID `com.walgak.alieninvasion`. Install the matching Godot iOS export template and Xcode, then run from the repository root:

```sh
mkdir -p build/ios
godot --headless --path mobile --export-debug iOS ../build/ios/AlienInvasion.zip
open build/ios/AlienInvasion.xcodeproj
```

Select your paired iPhone in Xcode and Run. The phone must have Developer Mode enabled and remain unlocked for installation/launch. Wireless deployment works with a paired device on the same network. If a development profile expires, let Xcode renew it with automatic signing before reinstalling. iOS may require trusting the renewed developer profile in Settings → General → VPN & Device Management. Build output is ignored by Git. This is development signing, not an App Store release. See [Godot's iOS export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).
# Drop progression

Drop rates above are the 50% reference. They scale with difficulty: at 1%, basic weapon and life drops each have a 0.04% chance per kill, and advanced upgrades have a 0.01% chance. At 50%, these reach 2%, 2%, and 0.5%. The advanced drop cap still applies; each regular or summoned swarm guarantees a drop on its first defeated alien, and each boss guarantees one drop. Extra drops retain these scaled chances.

Shooting and explosion effects use a low-bass palette. Gravity spawns and boss deaths descend to an 18 Hz sub-bass tail with audible harmonics; a dedicated impact voice prevents gunfire from interrupting them. Guaranteed rewards choose weapons or life pickups while preserving the one-advanced-weapon-per-boss-interval limit. At a full pickup budget, the oldest uncollected pickup is replaced by the guaranteed reward.

## Presentation and code

The game remains 2D. Detailed player and alien sprites have baked armor depth, blue/violet engine plasma, and matching weapon hardpoints. Black-hole particles spiral inward; white holes emit them outward, with spin matching the disk. Gravity taps, shields, tethers and screen edges use soft plasma and background refraction rather than line strokes. White departures always release light, including the edge bubble. Rounded iPhone edges use the safe-area geometry; desktop edges remain square.

Ship deaths bend, stretch and snap the textured hull, ignite a fire explosion, then expand a distortion wave beyond the screen before showing the menu. Black event horizons mask every fragment and fire pixel inside the core. Black-hole engine burn increases strongly with proximity; player engines stay blue. Lighting remains consistent within each sector and changes gradually between sectors.

See the [code guide](../docs/CODE_GUIDE.md) for ownership, tuning and test commands, the [fighter assets](assets/ships/README.md) for sprites and prompts, and the [gravity assets](assets/effects/README.md) for accretion textures. Artifacts in `build/` are generated and ignored by Git.
