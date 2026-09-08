# Working on Alien Invasion

The current game is in `mobile/`. The Python files at the repository root are the original practice game and run independently; editing them does not change the iPhone app. Source functions are commented throughout both versions.

## Start reading here

1. Open `mobile/project.godot` in Godot and run the project.
2. Read `mobile/scripts/game.gd`: it owns the run, actor lists, collisions and encounter schedule.
3. Read `boss.gd` for boss phases, then `weapon_system.gd` and `game.update_laser()` for weapons.
4. Change one tuning value, run a relevant test, and try the result in the game.

## Ownership and update order

`main.tscn` instantiates the game node. The game creates the ship, UI, background, sound manager and actors. Actor arrays contain live nodes; remove a node from its array before calling `queue_free()`. Queued nodes still exist until the end of the frame, which is why mutation-sensitive loops use `duplicate()` or membership checks.

Godot calls `_physics_process(delta)` for gameplay and `_process(delta)` for visuals. Delta is seconds. Positions are logical viewport pixels, velocities are pixels/second, and timers are seconds. Multiply velocity by delta exactly once. The game's visual clock stops when paused, including shader animation.

The physics loop updates the encounter director, player movement, live boss, detached attacks, enemies, rocks, ordinary shots, continuous laser, and pickups in that order. The order matters: shield removals and boss deaths can change what later collision checks may hit.

## Encounters and the shield

The director alternates regular flight, a three-second warning, a boss, and recovery. A shuffled deck includes each of the four boss kinds once. Surviving aliens are marked `shield_guard` during the warning and assigned evenly spaced orbit angles when the boss enters. They move physically to their orbit and retain their existing health and reward group.

`boss_is_shielded()` is the single rule for invulnerability. Both generic damage and direct boss damage enforce it. The laser excludes the boss while guards remain, so hidden exposure cannot accumulate.

Boss phases are `arrival → firefight → warning → active → firefight`. Summoned barrages add a `clearing` phase. Their thrown objects must leave or be destroyed before normal shooting resumes.

## Death does not clear attacks

`defeat_boss()` pays score and one reward once. It copies an unfinished special into a detached boss node with `lingering = true`, then removes the actual boss. Existing shots and rocks also remain. Detached nodes render their attack without a boss body and free themselves instead of restarting a firefight.

Black/white bosses additionally leave a 1.8× core with an eight-second lifetime at the death position. Black death particles move inward; white particles move outward. The original well keeps its own position and remaining lifetime. One tap neutralises every active well; it never moves the ship.

The ship's return flag is set at victory. Active gravity takes priority; once it ends, the ship moves toward `cruise_position()` at 260 pixels/second. The director waits until detached attacks and return motion finish. `restore_cruise_position()` is the separate instant reset used for emergency revival.

## Weapons and damage

Weapon levels are 0 single, 1 double, 2 triple, 3 laser, 4 rockets. Single/double/triple bullets all use 850 pixels/second and a 0.17-second interval. Rockets use 660 pixels/second, direct damage plus splash, and their own interval.

The laser is one persistent visual node, not a stream of projectiles. Each physics step updates its endpoints and a dictionary of target exposure. A non-boss needs 0.25 uninterrupted seconds, regardless of its health. Leaving the beam clears its accumulated exposure. An unshielded boss loses one health per 0.25 seconds; longer steps account for multiple intervals. The beam pierces targets. Offscreen/arriving actors are rejected before exposure or ordinary damage.

The ship draws wider hulls and matching barrels for each upgrade. Its collision radius stays small and constant so an upgrade does not make dodging unexpectedly harder. New shapes belong in `ship._draw()`; projectile muzzle positions belong in `weapon_system.fire()`.

## Tuning map

| Change | Location |
| --- | --- |
| Boss health curve, alien/rock health, wave timing | `game.gd`: spawn/director methods |
| Shooting frequency and extra drop progression | `difficulty_scale()` and their callers |
| Guaranteed drops and advanced-tier limit | `guaranteed_drop()`, `maybe_drop_pickup()` |
| Gravity force, tap duration and attack length | `boss.gd` constants and `step()` |
| Smooth return speed | `game._physics_process()` |
| Laser contact duration and boss damage | `game.update_laser()` |
| Bullet patterns/speed | `weapon_system.gd` |
| Ship appearance | `ship.gd` |
| Boss shield orbit size/speed | `game.update_enemies()` |
| Sound pitch, duration and volume | `sound.gd` |
| Planet travel, colors, stars | `shaders/space_background.gdshader` |
| Fold distortion | `space_folds.gd` and its matching shader |

Health progression: small aliens start at 3 and gain one hit every two victories, capped at 9. Rocks start at 5/8/12 by size and gain one every two victories. Bosses use `floor(100 - 780 / (12 + victories))`, capped at 99. The underlying curve starts at 35 and approaches 100. Difficulty begins at 1%; the 50% reference is used for firing and extra drops.

## Audio and rendering performance

Sounds are synthesized once and cached, not rebuilt for every shot. Regular effects share a small voice pool. Ship hits and gravity/death impacts use dedicated voices; the laser uses a looping electric channel. Pause and mute must stop every applicable channel. Volumes are decibels: a less-negative value is louder.

Ordinary bullet geometry is cached while the node moves. Only animated beam/rocket graphics request repeated redraws. Particles cap at 256 and pickups at 12. Preserve those bounds when adding effects. Background refraction has fixed capacities of eight lenses and six strands; change both controller and shader together if adjusting them. Draw order keeps HUD and actors sharp above the distorted background.

## Tests, saves and iPhone builds

From the repository root:

```sh
ALIEN_SAVE_PATH=/tmp/boss-evolution-record.cfg godot --headless --path mobile --script res://tests/boss_evolution.gd
ALIEN_SAVE_PATH=/tmp/hole-physics-record.cfg godot --headless --path mobile --script res://tests/hole_physics.gd
```

Each test has its own expected temporary filename. Never point tests at your real `user://flight_record.cfg`. Headless tests verify rules, not phone GPU performance. `tests/capture.gd` uses a real graphical renderer; set `ALIEN_CAPTURE_DIR` to an existing directory. Test touch and sound on the actual phone after a build.

See `mobile/README.md` for the iOS export workflow. The `build/` directory is generated and ignored by Git. Re-export the PCK after changing scripts, rebuild/sign the Xcode app, then install it on the paired phone. Comments and test files do not require a new runtime feature, but code changes do.

## The original Python version

`alien_invasion.py` owns a 60 FPS Pygame loop. `settings.py` holds its separate tuning values; `ship.py`, `alien.py`, and `bullet.py` are actors. `game_stats.py`, `scoreboard.py`, and `button.py` handle state and display. Unlike the Godot version, this older code uses per-frame movement and does not save its high score to disk. Its existing method docstrings and added module comments explain these differences.
