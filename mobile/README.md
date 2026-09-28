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

Each tap fully cancels the hole's force for a brief beat. Keep tapping to hold the current position exactly. Tapping never pushes the ship away and never recovers ground lost; when the tap window expires, the pull or push resumes at full strength. The shield warp and engine response show resistance without an obstructing instruction panel.

Both gravity holes form in the lower-middle region (28–72% screen width, 57–70% screen height). Cannons aim at a fixed point rather than tracking the ship. A clearance check redirects an unsafe landing before the core opens. White holes push away from their core, usually downward. Any of the four edges can destroy the ship, and surviving each attack schedules a smooth return to cruising height without resetting horizontal position.

**Mouse:** click and drag to steer; click repeatedly to neutralise a hole.

**Keyboard:** arrow keys or A/D to steer; press Space repeatedly to neutralise a hole. P/Esc pauses and resumes. Enter launches a flight. Holding Space does not count as repeated taps.

Pause also activates when the application loses focus. The endless high score saves locally and persists between runs. The title and pause screens have saved controls for sound, vibration, screen shake, laser brightness, and gravity distortion. There are no accounts, advertisements, analytics, or network requests in the game.

## Prototype scope

This is a desktop-playable project with mobile input and a portrait layout. It is not an App Store/Google Play release but supports a signed iPhone development installation. Physical-device touch feel, cutouts, interruptions, audio behavior, battery use, and difficulty still need to be tested. An Android debug APK preset uses the local debug keystore; release signing is not configured. The iOS preset exports an Xcode project for development signing with the configured Apple team.

### Special weapons

- **Gravity:** eligible alien kills charge the button: 10 kills unlock the smallest hole and 50 fill it. Press the button to open a three-second targeting window. A tap-and-release in the safe upper half chooses a destination and starts a one-third-second muzzle charge. Without a selection, the cannon fires automatically at **3 seconds** toward the middle of the upper half; its charge animation plays during the final third-second of that window. Existing steering continues, and new touches in the lower half can steer while targeting. Pressing the button again cancels. Charge is spent only on launch. A single hole lasts **3–7.5 seconds**; charge changes size and duration, never pull strength. Hole absorption and annihilation kills do not recharge it. Pause, death, restart or newly active unshielded gravity cancel a pending shot without spending its bank.
- **Laser:** collect up to 99 charges. Its button selects a ten-second firing budget; lifting the steering finger pauses the clock. Toggle back to the primary guns and resume the same remaining budget later. Expiry restores the previous weapon and never automatically spends another charge.
- **Electron:** special pickup from bosses or a qualifying large-asteroid family, up to 10 stored charges. The beam chains from the alien nearest the gun column through visible aliens and asteroids. Rocks melt without fragments. A boss takes one cannon-equivalent hit after its guards are gone.
- **Cannons:** start with 30; drops add five, up to 99. Tapping an enemy fires one homing cannon. With at least five in stock, the button launches a volley at visible small aliens, prioritizing those nearest escape. It spends only the available ammunition needed for their health, accounting for cannons already in flight. Both controls share one inventory.

The primary progression is **single → double → triple → enhanced triple plasma**. All primary bullets travel at 850 units/second with a 0.17-second cadence. Normal bullets deal one damage, enhanced plasma two, and cannons three plus splash within 65 pixels. The continuous laser instantly kills small aliens, deals one boss hit per 0.25 seconds, and reflects away from the player when it touches asteroids. It also pushes asteroids, with a stronger effect on small rocks.

Hull lives have a strict maximum of three; health pickups refill them and weapon upgrades grant no backup life. Alien contact destroys the alien with an electrical discharge and costs one life. Unprotected asteroid contact and an escaped alien's homing gravity cannon are instant losses.

Forced gravity tapping automatically supplies a hazard ward that deflects bullets and rocks and zaps nearby small aliens. It does **not** protect from the gravity core or lethal white-hole boundary. A collected ten-second shield also grants gravity immunity, steering and firing, including special weapons. Swarm shields drop at one third the hull-repair rate; bosses always supply a shield. The protected dome zaps a small alien when its silhouette reaches one pixel outside its circumference; swept contact checks run before escape, so a fast ship cannot slip through between frames. The bolt branches from the shield rim. Without protection, the contact zap waits for an actual ram and costs one life. Escaped-alien cannons are absorbed by a protected ship and produce an outward visual ripple. Only asteroids redirected by the player’s hole, shield/ward or laser can damage enemies: small aliens die; bosses take one cannon’s damage, respecting their alien guards. Fragments retain this ownership.

After the last hole closes, a brief bounded thruster recoil precedes smooth recovery to the normal cruising **Y** position while retaining the resulting X. Recovery waits for all overlapping gravity to end, including when a collected shield is active. Bosses recruit only aliens above the screen midpoint; lower aliens continue forward. Bosses dodge player event horizons with smooth continuous motion and may retreat above or beside the screen. They keep full hull clearance while fields move or merge, then return smoothly when a safe route opens. Their gravity-only distortion shield does not change ordinary weapon damage.

Final art, difficulty balancing, and store submission remain future work. Hole attacks temporarily replace dragging with tapping; that control switch and the tapping intensity are the main things to playtest. The tap rate and attack timing are tunable in `scripts/boss.gd`.

## Code guide

- `combat_controls.gd`: independent steering/target fingers, special inventories, hazard ward and return bookkeeping.
- `death_visual.gd`, `impact_visual.gd`: textured hull failure, fire, pressure wave and pooled electrical contact effects.

- `game.gd`: run state, input, scoring, spawning, collisions, and app lifecycle.
- `ship.gd`, `enemy.gd`, `projectile.gd`: arcade actors and summoned alien motion.
- `weapon_system.gd`, `pickup.gd`: weapon patterns, upgrade levels, and collectible drops.
- `boss.gd`, `asteroid.gd`: the four boss mechanics and destructible rocks.
- `space_background.gd`, `space_folds.gd`, `shaders/`: layered procedural sky and background refraction. One screen-reading pass combines up to eight object lenses and six strands; actors and HUD render above it. Animation uses game time so pausing also freezes the folds.
- `interface.gd`: menus, floating score/pause, and circular special-weapon input routing.
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

Difficulty begins at 1% and rises by one point per boss defeated. It changes enemy firing frequency and drop chances, while movement, wave timing, bullet speeds, and gravity strength stay constant. Small aliens always take 3 normal bullet damage and show wreckage, then smoke, before exploding. Asteroids begin at 5/8/12 hits by size and gain one hit every two victories. Boss health follows floor(100 - 780 / (12 + victories)): 35, 40, 44, 48… with a 99-hit ceiling. The underlying curve approaches 100 without reaching it. Single/double/triple bullets all travel at 850 units/s with a 0.17-second firing interval. Rockets travel at 660 units/s; the ten-second laser instantly kills aliens, pushes asteroids and reflects away from the player, and deals one boss hit per 0.25 seconds. Original flight music switches to boss music during encounters. Planets drift through the sky and are replaced after passing offscreen.

## iPhone development build

The iOS preset uses bundle ID `com.walgak.alieninvasion`. Install the matching Godot iOS export template and Xcode, then run from the repository root:

```sh
mkdir -p build/ios
godot --headless --path mobile --export-debug iOS ../build/ios/AlienInvasion.zip
open build/ios/AlienInvasion.xcodeproj
```

Select your paired iPhone in Xcode and Run. The phone must have Developer Mode enabled and remain unlocked for installation/launch. Wireless deployment works with a paired device on the same network. If a development profile expires, let Xcode renew it with automatic signing before reinstalling. iOS may require trusting the renewed developer profile in Settings → General → VPN & Device Management. Build output is ignored by Git. This is development signing, not an App Store release. See [Godot's iOS export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html).
## Android test APK

The `Android` export preset produces `build/android/AlienInvasion-debug.apk` with package ID `com.walgak.alieninvasion`, ARMv7/ARM64 support, vibration permission and no internet permission. It uses the standard Godot APK template without a custom Gradle build.

Install the Android export templates matching the Godot version, a supported Android SDK and JDK. Set their paths and the debug keystore under Godot's **Editor Settings → Export → Android**. From the repository root:

```sh
mkdir -p build/android
godot --headless --path mobile --export-debug Android ../build/android/AlienInvasion-debug.apk
```

An Android device can install the generated debug APK through its normal sideloading workflow. Debug signing is for testing; a private release key and Google Play AAB export are separate release work. Never commit keystores, credentials or generated build output. Exporting an APK does not verify physical-device rendering, touch or haptics.

## Drop progression

Every regular or summoned swarm guarantees a support drop on its first defeated alien. Optional additional support drops use a 4% chance at the 50% difficulty reference, capped at 12%. Their roll chooses primary upgrades or support (hull repair, cannon ammunition, shield). Swarms never drop laser/electron weapons.

Every boss drops exactly **one special weapon, one gun upgrade, and one shield**. The special is electron with a 30% chance, otherwise laser. Guaranteed rewards replace the oldest uncollected pickup when the bounded pickup pool is full.

Destroying a large asteroid and all of its fragments with primary guns earns one special pickup on the last fragment, using the same electron/laser roll. Primary bullets and enhanced plasma qualify. A non-primary hit anywhere in that family, swallowing, escape or collision removal cancels the bonus for all descendants. Pure deflection does not cancel it. Standalone medium and small rocks cannot earn this reward.

Shooting and explosions use a low-bass palette. Gravity spawns and boss deaths descend to an 18 Hz sub-bass tail with audible harmonics; dedicated impact voices prevent gunfire from interrupting them.

## Presentation and code

The game remains 2D. Detailed player and alien sprites have baked armor depth, blue/violet engine plasma, and matching weapon hardpoints. Black-hole particles spiral inward; white holes emit them outward, with spin matching the disk. Gravity taps, shields, tethers and screen edges use soft plasma and background refraction rather than line strokes. White departures always release light, including the edge bubble. Rounded iPhone edges use the safe-area geometry; desktop edges remain square.

Ship deaths begin by folding the textured metal inward. Bullets cause a quick buckle; asteroid and alien impacts crush the hull; black holes draw it into the horizon; white holes compress it against the screen boundary. The following fire explosion, outward fragments and expanding distortion wave remain visible before the menu appears. Black event horizons mask every fragment and fire pixel inside the core. Black-hole engine burn increases strongly with proximity; player engines stay blue. Lighting remains consistent within each sector and changes gradually between sectors.

See the [code guide](../docs/CODE_GUIDE.md) for ownership, tuning and test commands, the [fighter assets](assets/ships/README.md) for sprites and prompts, and the [gravity assets](assets/effects/README.md) for accretion textures. Artifacts in `build/` are generated and ignored by Git.

The right-side circular glass buttons use icons and small inventory counters. An existing steering drag always retains ownership when crossing them. While gravity is armed, new lower-half touches also steer and only upper-half taps select a target. Each successful button action emits one short, weapon-specific haptic; unavailable clicks do not claim a successful launch, and the vibration toggle mutes every pulse. The top information bar and gravity instructions are removed; score and pause remain unobtrusive.

Multiple gravity fields pause their lifetimes until interaction resolves: black cores join through a liquid neck and overlapping lobes before merging, mixed cores annihilate safely, and white centers repel while expanding pressure fronts meet and discharge. Enemy hole size increases gradually with difficulty, with a safe cap. Bullet cores absorb/deflect energy; laser branches bend around both sides without multiplying boss damage.

Stationary stars render behind the nebulae and are never warped. Nearby solar wind forms smooth translucent clouds, with brightness reduced to 10% of the earlier particles and intensity varying by sector. Planets, moons and gas have subtle tidal effects. The shield combines a bright blue hex grid, shifting color and electrical flow with exaggerated transparent distortion, sized to fit every upgraded hull. Its diffuse haze is reduced to 10% of its previous brightness so the shell remains readable without obscuring the ship.
