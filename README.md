# Alien Invasion

A space shooter that began as a Python/Pygame practice project and is being developed into a portrait mobile game with Godot.

The current Godot prototype is an endless high-score shooter with random alien groups, drifting asteroids, and four bosses. It runs locally on desktop and supports touch input. An iOS development export preset is included; store submission remains future work.

## Play the Godot game

Install **Godot 4.7**; development and local checks use **4.7.2**.

1. Open `mobile/project.godot` in Godot.
2. Press **F5**.
3. Select **Launch endless flight**.

On macOS, you can also double-click [`mobile/Play.command`](mobile/Play.command). The launcher imports the project on its first run and starts the game. On any platform with the Godot CLI installed:

```sh
godot --headless --path mobile --editor --import --quit
godot --path mobile
```

### Controls

| Input | Steering | Block a hole | Pause |
| --- | --- | --- | --- |
| Touch | Drag horizontally | Tap repeatedly | Pause button |
| Mouse | Click and drag | Click repeatedly | Pause button |
| Keyboard | Arrow keys or A/D | Press Space repeatedly | P or Esc |

Weapons fire automatically. During a hole attack, tapping temporarily replaces steering. Holding a button does not count as repeated taps.

Each tap fully cancels a hole's force for a brief beat. Keep tapping to hold the ship exactly where it is. Tapping never pushes the ship away and never recovers distance already lost; when the tap window expires, the pull or push returns at full strength.

## Boss fights

**Exchange fire → randomly timed special attack → survive → exchange fire again.** This cycle repeats until the boss has no health left. Only player shots hitting the boss damage it. Surviving an attack does not reduce its health, and health never resets between cycles.

- **Black hole:** the boss fires a fast rift cannon that folds space, detonates beside the ship, and creates the hole. Repeated taps neutralise the pull. Being pulled into its core is lethal unless a weapon upgrade supplies an emergency life.
- **White hole:** the boss fires its rift cannon into a fixed lower-middle area. The blast creates a white hole that pushes away from its core, usually downward. All four edges remain dangerous. Repeated taps neutralise the push; reaching an edge destroys the ship.
- **Asteroid forge:** space-fold strands connect the boss to rocks offscreen, pulling them inward before a brief wind-up and sling toward the ship. The strands fade after release. Small, medium, and large asteroids take 5, 8, and 12 shots initially to destroy. Once the barrage is cleared, the firefight resumes.

- **Swarm carrier:** pulls alien ships from offscreen on boss-connected folds, then throws them toward the player. These ships can shoot and can be dodged or destroyed.

Random enemy groups and asteroids keep arriving between bosses. About 45% of regular aliens zigzag, and aliens fire every 1.05–1.9 seconds. Boss music gives a three-second warning before an entrance, roughly every 40–55 seconds of regular flight. Each set of four bosses contains all four types in shuffled order. Defeating a boss awards points, drops one pickup, clears its hazards, and continues the run. Gravity-boss victories restore the ship to its normal position.

## Drops and survival

Collect weapon drops to advance **single → double → triple → laser → rockets**. Lasers pierce targets; rockets deal splash damage. Enemy kills randomly drop upgrades or hull repairs; extra basic weapon drops have a 2% chance; laser/rocket progression has a 0.5% chance and a shared maximum of one drop per boss interval. Hull repairs restore one life up to a maximum of three.

Upgrades collectively provide one emergency life: losing the last hull life consumes the weapon upgrade, restores the single shooter, and leaves one hull life. Ordinary hits preserve the weapon. Another lethal hit without an upgrade ends the run. Surplus pickups at maximum capacity award points.

Space folds refract a textured starfield, nebula, and shaded planet. Black-hole ripples travel inward and white-hole ripples outward; their lit ridges bend the background into an elliptical well. The rift cannon, asteroid tethers, and folded rocks also distort the sky behind them. Ships, bullets, and controls remain sharp above the effect.

![A boss exchanging fire with the player](docs/screenshots/firefight.png)
![Black-hole space folds collapsing inward](docs/screenshots/black.png)
![White-hole space folds expanding outward](docs/screenshots/white.png)

The game includes pause on focus loss, hit effects, original synthesized sound, and a persistent local endless high score. The rift cannon uses a high-to-low sci-fi blast made in code. There are no accounts, ads, analytics, or network requests in the game.

## Project structure

```text
mobile/
  project.godot       Godot project entry point
  main.tscn           Main scene
  scripts/            Game rules, actors, bosses, UI, saves, and sound
  tests/              Gameplay, input-routing, and boss-cycle checks
  Play.command        Mac launcher
docs/screenshots/     Actual Godot screenshots
*.py                 Original Python/Pygame game
images/              Original Python artwork
```

See [the Godot project guide](mobile/README.md) for the code map, tuning notes, and mobile export requirements. Open `alien-invasion.code-workspace` in VS Code or Cursor to work with the complete repository.

## Run the checks

Use disposable save files so tests do not overwrite your flight records:

```sh
ALIEN_SAVE_PATH=/tmp/alien-smoke-record.cfg godot --headless --path mobile --script tests/smoke.gd
ALIEN_SAVE_PATH=/tmp/alien-input-record.cfg godot --headless --path mobile --script tests/input_flow.gd
ALIEN_SAVE_PATH=/tmp/alien-boss-cycle-record.cfg godot --headless --path mobile --script tests/boss_cycle.gd
ALIEN_SAVE_PATH=/tmp/alien-hole-physics-record.cfg godot --headless --path mobile --script tests/hole_physics.gd
ALIEN_SAVE_PATH=/tmp/alien-endless-record.cfg godot --headless --path mobile --script tests/endless.gd
```

Checks cover scoring, lives, restart, saves, pause, touch ownership, GUI input, swept collisions, hole neutralisation and failure, destructible asteroids, repeated boss cycles, and projectile-only boss damage.

## Run the original Python game

From the repository root, create a virtual environment, install `requirements.txt`, and run:

```sh
python -m pip install -r requirements.txt
python alien_invasion.py
```

Use the left/right arrow keys to move, Space to shoot, and Q to exit. The original practice version remains available alongside the Godot project.

## Release status

This is a playable development prototype, not a signed Android/iOS release. It has been checked locally on macOS; physical-phone testing, final artwork, difficulty tuning, export configuration, signing, and store submission remain. The Godot prototype uses original procedural graphics and synthesized sounds; original Python artwork is not bundled into the Godot game.

Difficulty begins at 1% and rises by one point per boss defeated. It changes enemy firing frequency and drop chances, while movement, wave timing, bullet speeds, and gravity strength stay constant. Small alien ships take 3 hits initially, gaining one hit every two victories up to 9. Asteroids begin at 5/8/12 hits by size and gain one hit every two victories. Boss health follows floor(100 - 780 / (12 + victories)): 35, 40, 44, 48… with a 99-hit ceiling. The underlying curve approaches 100 without reaching it. Single/double/triple bullets all travel at 850 units/s with a 0.17-second firing interval. Rockets travel at 660 units/s; lasers are instantaneous pulses. Original flight music switches to boss music during encounters. Planets drift through the sky and are replaced after passing offscreen.
# Drop progression

Drop rates above are the 50% reference. They scale with difficulty: at 1%, basic weapon and life drops each have a 0.04% chance per kill, and advanced upgrades have a 0.01% chance. At 50%, these reach 2%, 2%, and 0.5%. The advanced drop cap still applies; each regular or summoned swarm guarantees a drop on its first defeated alien, and each boss guarantees one drop. Extra drops retain these scaled chances.

Shooting and explosion effects use a low-bass palette. Gravity spawns and boss deaths descend to an 18 Hz sub-bass tail with audible harmonics; a dedicated impact voice prevents gunfire from interrupting them. Guaranteed rewards choose weapons or life pickups while preserving the one-advanced-weapon-per-boss-interval limit. At a full pickup budget, the oldest uncollected pickup is replaced by the guaranteed reward.
