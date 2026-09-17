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

`boss_is_shielded()` is the single rule for invulnerability. Both generic damage and direct boss damage enforce it. The laser excludes the boss from damage while guards remain, so hidden exposure cannot accumulate. A visible shield and guard-to-boss strands weaken with the surviving guard fraction; laser rays terminate at that shield.

Boss phases are `arrival → firefight → warning → active → firefight`. Summoned barrages add a `clearing` phase. Their thrown objects must leave or be destroyed before normal shooting resumes.

## Death does not clear attacks

`defeat_boss()` pays score and one reward once. It copies an unfinished special into a detached boss node with `lingering = true`, then removes the actual boss. Existing shots and rocks also remain. Detached nodes render their attack without a boss body and free themselves instead of restarting a firefight.

Black/white bosses additionally leave a 1.8× core with an eight-second lifetime at the death position. Black death particles move inward; white particles move outward. The original well keeps its own position and remaining lifetime. One tap neutralises every active well; it never moves the ship.

The ship's return flag is set at victory and after every survived white-hole attack, even while the boss remains alive. Active gravity takes priority; once it ends, the ship moves toward `cruise_position()` at 260 pixels/second, giving the player distance from the boundary before the next push. The director waits until detached attacks and return motion finish. `restore_cruise_position()` is the separate instant reset used for emergency revival.

## Weapons and damage

Weapon levels are 0 single, 1 double, 2 triple, 3 temporary laser, 4 rockets. Permanent upgrades skip level 3. `combat_controls.gd` remembers the previous weapon and restores it after ten seconds of held firing; another laser refreshes the timer, and permanent upgrades collected during the laser improve the remembered weapon. Single/double/triple bullets all use 850 pixels/second and a 0.17-second interval. Rockets use 660 pixels/second, direct damage plus splash, and their own interval.

The laser is one persistent visual node, not a stream of projectiles. Each physics step updates its endpoints and a dictionary of target exposure. Ordinary aliens die immediately. Asteroids are unharmed and reflect the beam at their surface; a downward reflection is redirected along the outward tangent so it cannot reach the player. The ray trace has at most 96 short steps and three asteroid reflections. All ray steps bend through gravity. Leaving the beam clears accumulated boss exposure. An unshielded boss loses one health per 0.25 seconds; longer steps account for multiple intervals. The beam pierces small aliens, but stops at boss hull/shield surfaces with an animated absorption glow. Three animated filaments share a bounded polyline rather than allocating a projectile stream. Offscreen/arriving actors are rejected before exposure or ordinary damage.

The ship draws wider hulls and matching barrels for each upgrade. Its collision radius stays small and constant so an upgrade does not make dodging unexpectedly harder. New shapes belong in `ship._draw()`; projectile muzzle positions belong in `weapon_system.fire()`.

## Touch controls, fatal hazards and player gravity

`combat_controls.gd` owns one active pointer. Holding the ship/lower flight region fires; dragging steers; release or leaving the viewport cancels control and the old movement target. Enemy taps launch homing rockets from an inventory of 30 at run start. Each targeted launch consumes one; missile pickups add five. The permanent rocket weapon remains separate. All rocket explosions deal three damage within 65 pixels, so one blast can destroy adjacent three-hit aliens. An upper-field hold of 1–5 seconds launches a gravity rocket on release, provided the position is outside the lower 28% and at least 75 pixels from the ship. A second finger cannot change the first gesture. `_input()` handles release before GUI consumption; presses use `_unhandled_input()` so menus keep their clicks.

Active gravity cancels equipped fire and targeting unless a shield is active. An active shield also permits charging a gravity counterattack; when it expires, tap-only controls resume. Taps neutralise all wells without applying thrust. Ordinary aliens stop shooting during gravity; bosses resist player gravity and retain their attacks. `player_well.gd` flies the charged rocket at 1225 pixels/second, opens a well for 1.5 times the charge duration (1.5–7.5 seconds), and pulls non-boss actors with a gentle two-second acceleration from 77.4 to 90 pixels/second, independent of charge size. Its minimum core matches the 1.8× boss death well; radius scales with the square root of charge. Surviving ships' pre-well positions are stored once and restored at 260 pixels/second. The player restores only Y, preserving horizontal position; asteroids instead keep their gravity-modified velocity and never restore position. Deleted actors are never revived. `combat.controls_actor()` suspends ordinary movement during pull and restoration. Shots instead bend toward black holes or away from white holes while preserving speed.

Asteroid contact and an escaped alien's homing doom cannon call `instant_loss()`, bypassing hull, upgrade backups and normal hit invulnerability. Asteroids exiting the screen do nothing. Direct alien contact still costs one hull. A ten-second shield blocks all damage and gravity movement; it is not consumed on contact. Support rewards first have a 25% chance to supply five targeting missiles. Remaining support rewards choose hull/shield with 75%/25% probability, keeping shields at one third of the hull rate. Each swarm and boss still guarantees a drop; laser/rocket rarity shares the sector allowance.

`combat.vibrate()` uses a rate-limited enemy-death tick, a continuous low-amplitude gravity rumble and a double hit pulse. Black-hole spawning adds a single pop; white-hole spawning schedules three irregular pops before the rumble. Enemy feedback never clears and restarts the active gravity rumble: doing so flooded the iOS haptic engine and stalled touch delivery during dense fights. The queue is bounded and muted by the saved vibration preference independently of sound. iOS supplies the physical feedback through Godot's `Input.vibrate_handheld`; evaluate its feel on the device.

The title and pause menus persist three accessibility presentation controls through `progress.gd`: screen shake on/off, reduced/full laser brightness, and reduced/full gravity distortion. `space_folds.gd` feeds shield rings, tap pulses, mixed-hole shockwaves, exit rings, boss shields, holes, and tethers into one bounded screen-reading pass. This keeps the effect visually consistent and caps the number of simultaneous lenses.

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
ALIEN_SAVE_PATH=/tmp/combat-rules-record.cfg godot --headless --path mobile --script res://tests/combat_rules.gd
ALIEN_SAVE_PATH=/tmp/boss-evolution-record.cfg godot --headless --path mobile --script res://tests/boss_evolution.gd
ALIEN_SAVE_PATH=/tmp/hole-physics-record.cfg godot --headless --path mobile --script res://tests/hole_physics.gd
```

Each test has its own expected temporary filename. Never point tests at your real `user://flight_record.cfg`. Headless tests verify rules, not phone GPU performance. `tests/capture.gd` uses a real graphical renderer; set `ALIEN_CAPTURE_DIR` to an existing directory. Test touch and sound on the actual phone after a build.

See `mobile/README.md` for the iOS export workflow. The `build/` directory is generated and ignored by Git. Re-export the PCK after changing scripts, rebuild/sign the Xcode app, then install it on the paired phone. Comments and test files do not require a new runtime feature, but code changes do.

## The original Python version

`alien_invasion.py` owns a 60 FPS Pygame loop. `settings.py` holds its separate tuning values; `ship.py`, `alien.py`, and `bullet.py` are actors. `game_stats.py`, `scoreboard.py`, and `button.py` handle state and display. Unlike the Godot version, this older code uses per-frame movement and does not save its high score to disk. Its existing method docstrings and added module comments explain these differences.

Godot 4.7’s iOS haptic implementation can log “Could not vibrate using haptic engine: (null)” even when feedback succeeds. This is an upstream logging bug, not a failed game assertion: https://github.com/godotengine/godot/issues/121614. The actual vibration feel still needs hands-on testing.

## Interacting fields and readable defeat

`gravity_interactions.gd` updates active fields before actor physics. Black fields attract at a bounded rate; touching cores merge using `sqrt(radius_scale_a² + radius_scale_b²)` and the sum of their **remaining** seconds. This keeps the launch charge cap separate from conserved merged area and duration. A player field owns the merged field when present so survivor bookkeeping is retained. White fields repel without changing their clocks. When multiple white fields exist, proximity raises force by up to 3× and shortens the neutralisation window by the same factor. Taps always cancel force completely.

Opposite cores cancel on contact, show a 0.35-second flash, then emit a local shockwave. It destroys nearby exposed aliens, deals five damage to exposed rocks/bosses, and clears nearby shots. It never calls player damage. Existing boss shields still gate boss damage.

Defeated tractor bosses leave a damaged glowing core at the original tether origin. The existing barrage finishes without being restarted, then the core burns out. Its strands retain background distortion.

`finish_run()` freezes gameplay but starts a 1.8-second death sequence before enabling menu buttons. Black-hole deaths crumble hull plates into the field; shots explode immediately, while ram and edge deaths crumble before exploding. The hull stays visible during ordinary recovery—invulnerability uses a ring rather than a potentially stuck blink. Recovery changes only height.

The sky shader receives one distant light vector shared by every body. Boss victory sets a new target direction and the visible illumination eases toward it gradually. No foreground suns are drawn.

Gravity expiry is evaluated before core/edge contact. Shielded contact must never return early forever and skip the expiration check. `tests/large_well_review.gd` covers this alongside maximum charge, freed actors, death animation, emergency revival and merged-well lifetime. `tests/large_well_stress.gd` runs a crowded maximum-charge encounter with real frame boundaries; it supports both headless and graphical execution.


## Render safety and destruction

`player_well.origins` and `combat.returns` use integer instance IDs, never Node keys. Resolve IDs with `instance_from_id()` only while updating gameplay, validate the result, and ignore queued/freed actors. The thrust drawing path iterates the live ship arrays only. A September 17 iPhone report showed a scene-update watchdog kill inside a GDScript redraw callback, with the gravity thrust validity/object-comparison/draw-line functions present. Avoid keeping destroyed actors in any render-loop iterator.

`death_visual.gd` triangulates the actual ship silhouette once. Gunfire explodes immediately; collision deaths crumble for 0.42 seconds before exploding; white-hole deaths crumble at the nearest boundary; black-hole deaths spiral hull plates into the core without an explosion. Gameplay freezes immediately; the menu waits 1.8 seconds. Its layer is below `gravity_interactions.gd`, which composites opaque event horizons last, preventing any hull, debris or beam from appearing inside a black hole. Nothing changes the scoring or damage rules during this presentation.

Expired wells enqueue finite visual-only exit effects. Black exits contract two folds, collapse, then release outward energy; white exits release outward energy immediately with two expanding folds. The shield/escaped-alien shockwave is explicitly marked `visual_only` and cannot call any damage or force function. Keep it separate from the enemy-damaging mixed-hole annihilation.

## Motion, sound and distant scenery

`combat.update_attitudes()` turns the player and affected aliens against gravity, then eases them back upright. White resistance points the nose toward the field; black resistance points away. Tap cancellation still removes the force completely. Boss black pull rises gently from 66 to 86 pixels/second; white push falls from 118 to 94. These retain the former average displacement budget.

`curved_velocity()` preserves each weapon's speed while bending direction. Homing rockets steer gradually so their guidance does not erase curvature each frame. The laser uses the same force sampled along short rays at its own constant effective speed. `sound.update_gravity()` provides an artistic sound counterpart using a low-pass filter, subtle pitch change and stereo deflection; music is unaffected.

There are no foreground suns. One light vector is shared by all celestial bodies, easing toward a new sector direction rather than snapping. Planets are spaced by 3,160 logical pixels at the normal viewport height and vary from 65 to 235 pixels in radius. Ocean, gas, ice and rocky worlds use different surface palettes/patterns. Only some have moons or rings. Ring pixels are composited behind or in front according to their tilted plane coordinate. Colorful nebulae remain distant and slow.

`tests/gravity_polish.gd` covers the new combat and presentation contracts; `tests/polish_capture.gd` captures real GPU frames. `tests/device_gravity_probe.gd` is an isolated on-device harness that renders three maximum-charge fields with swallowed actors and writes progress to its own `user://gravity_probe.txt`. It is excluded from normal exports and uses its own save file. Copy it to a temporary export project as the main scene for device verification, then reinstall the normal playable pack.
