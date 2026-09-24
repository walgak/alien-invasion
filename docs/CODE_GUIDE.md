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

The director alternates regular flight, a three-second warning, a boss, and recovery. A shuffled deck includes each boss once. `begin_boss()` recruits only aliens above `arena.y * 0.5`, preserving their health and reward group; they physically move into guard orbits. Lower aliens continue forward instead of reversing near the player.

`boss_is_shielded()` is the single rule for invulnerability. Both generic damage and direct boss damage enforce it. The laser excludes the boss from damage while guards remain, so hidden exposure cannot accumulate. A visible shield and guard-to-boss strands weaken with the surviving guard fraction; laser rays terminate at that shield.

Boss phases are `arrival → firefight → warning → active → firefight`. Summoned barrages add a `clearing` phase. Their thrown objects must leave or be destroyed before normal shooting resumes.

## Death does not clear attacks

`defeat_boss()` pays score and one reward once. It copies an unfinished special into a detached boss node with `lingering = true`, then removes the actual boss. Existing shots and rocks also remain. Detached nodes render their attack without a boss body and free themselves instead of restarting a firefight.

Black/white bosses additionally leave a 1.8× core with an eight-second lifetime at the death position. Black death particles move inward; white particles move outward. The original well keeps its own position and remaining lifetime. One tap neutralises every active well; it never moves the ship.

`request_cruise_return()` sets one recovery flag after every player/boss gravity closure and boss victory. It removes any stale ship entry from `combat.returns`. Once **all** active fields end, the physics loop restores only cruising Y at 260 pixels/second; X remains under normal steering. This also applies above the screen midpoint and while a full shield is active. The director waits for residual attacks and recovery to finish.

## Weapons and damage

Weapon levels are 0 single, 1 double, 2 triple, 3 temporary laser, 4 enhanced triple plasma. Permanent upgrades skip 3. All primary fire uses 850 pixels/second and 0.17-second cadence: normal bullets deal one damage, level 4 deals two. `combat.collect_laser()` banks a charge up to 99. `activate_laser()` selects or deselects a ten-second held-firing budget, preserving unused time. Expiry restores `previous_weapon` without consuming another charge. Permanent pickups improve that remembered tier while a laser is active. Cannons are separate inventory, travel at 660 pixels/second and deal three direct/splash damage.

The laser is one persistent visual node. Its trace has at most 96 short gravity-curved steps and three asteroid reflections. Small aliens die on contact; an unguarded boss loses one health per 0.25 seconds of continuous exposure. Boss hull/shield surfaces absorb the beam with an animated contact glow. Asteroids reflect it away from the player and receive `180 * (20/radius)^2 * delta` momentum, bounded to 550 pixels/second. Preview traces use delta zero and cannot alter physics. Filled animated ribbons replace the old polylines. `visible_shot_intersects()` clips each shot/beam segment to the actual playfield before testing the target circle; visible portions of edge targets work, while entirely offscreen contacts and boss arrival damage remain blocked.

The ship draws wider hulls and matching barrels for each upgrade. Its collision radius stays small and constant so an upgrade does not make dodging unexpectedly harder. New shapes belong in `ship._draw()`; projectile muzzle positions belong in `weapon_system.fire()`.

## Touch controls, fatal hazards and player gravity

`combat_controls.gd` owns one steering pointer plus independent targeting taps in `aim_touches`. Holding the ship/lower region fires; dragging steers; release or leaving the viewport stops control. `interface.route_special_touch()` handles each button pointer explicitly before GUI mouse emulation can steal a second finger. `_input()` routes owned releases once. Enemy taps consume one shared cannon; the button requires at least five and allocates only needed available ammunition to visible small aliens, nearest escape first, reserving damage from cannons already in flight. Start stock is 30, drops add five, cap 99. Blast radius is 65 pixels.

`add_gravity_charge()` banks eligible alien kills from 0 to 50. Ten unlock the button. `arm_gravity()` makes the next safe playfield tap a destination; release reserves its charge and starts a one-third-second particle/refraction preparation. Ordinary steering release does not cancel it; pause, death, restart, or newly active unshielded gravity does, without spending charge. A full shield permits counterattacks. `launch_gravity()` consumes the reservation and fires at 1225 pixels/second. `player_well.lifetime_for_charge()` maps charge factors 1–5 to 3–7.5 seconds; core scale remains `1.8 * sqrt(charge)`. Pull strength stays independent of charge. Hole absorption and safe annihilation call `destroy_enemy(enemy, false)` to prevent self-funding gravity chains.

Player wells store pre-pull positions only for surviving non-player actors. Ship recovery always uses the cruising-height path; asteroids keep changed velocity and never return to their old positions. Bosses stay outside all player event horizons through `safe_player_well_position()` with full visual-hull clearance, including growing merged holes. Their gravity-only warp does not block ordinary damage. Taps fully neutralise every active field without moving the ship or firing.

`combat.hazards_protected()` means either forced tapping or a collected full shield. The automatic ward deflects incoming shots, rocks and alien contact, but cores and white edges remain lethal. The ten-second pickup shield additionally allows movement, firing and gravity immunity. Outside protection, asteroid/doom-cannon contact is instant loss; ordinary fire and alien collision cost one hull. `handle_alien_collision()` destroys a contacted alien and triggers a pooled electric discharge. Lives refill to a maximum of three, and upgrades never revive the player. Support drops first have a 25% cannon chance; remaining rewards choose hull/shield at 75%/25%, preserving the 3:1 hull/shield ratio.

`asteroid.player_deflected` is set only after player-hole, shield/ward or laser momentum changes. `resolve_deflected_rock()` kills small aliens or applies three damage to a boss (guard gate respected), then shatters the rock once. Ambient rocks cannot damage enemies; fragments inherit ownership. Gravity still permanently changes rock trajectories.

`combat.vibrate()` uses a rate-limited enemy-death tick, a continuous low-amplitude gravity rumble and a double hit pulse. Black-hole spawning adds a single pop; white-hole spawning schedules three irregular pops before the rumble. Enemy feedback never clears and restarts the active gravity rumble: doing so flooded the iOS haptic engine and stalled touch delivery during dense fights. The queue is bounded and muted by the saved vibration preference independently of sound. iOS supplies the physical feedback through Godot's `Input.vibrate_handheld`; evaluate its feel on the device.

The title and pause menus persist three accessibility presentation controls through `progress.gd`: screen shake on/off, reduced/full laser brightness, and reduced/full gravity distortion. `space_folds.gd` feeds shield volumes, tap pulses, mixed-hole shockwaves, exit waves, boss shields, holes, and tethers into one bounded screen-reading pass. This keeps the effect visually consistent and caps the number of simultaneous lenses.

Characters and combat effects remain 2D. Shield and tapping effects are smooth background refraction plus a faint filled cyan halo, without geometric strokes. Hostile bullets curve around the shield without being absorbed; a deflected doom cannon also emits a harmless visual shockwave. The white-hole boundary shader follows the safe-area corner shape on iPhone and uses square desktop corners. Every white exit discharges this bubble with light. Black cores mask all actors and death fragments. Blue player disks and encounter-colored alien disks have shader particles whose inward/outward motion and spin match the accretion flow.

`accretion_visual.gd` and `accretion.gdshader` animate the committed luminance texture in `assets/effects/`. The image's black backdrop becomes transparent via sampled luminance; colour mapping supplies blue, alien, or white plasma. Two texture samples provide rotation and radial flow on each quad, with the simulation clock freezing animation during pause. `gravity_interactions.gd` reuses at most twelve sprites at layer -5 behind ships, then masks every actual core at layer 32 above ships and death fragments. The outer extent scales more slowly than core size to limit maximum-charge overdraw. Restart hides the pool rather than creating more nodes. Active well refraction has strength 1.4 and takes priority over cosmetic pulses in the eight-lens budget. `tests/accretion_capture.gd` verifies rendered core opacity, animation, actual refraction and lens priority.

`hull_finish.gd` provides the shared painted metal treatment for ships and bosses. Vertex colours shade each raised plate, opposite bevels have different brightness, and a slowly moving band simulates a reflection. Bright metal faces remain legible over space, while thin dark separators preserve silhouettes over planets. This helper has no gameplay state and creates no render nodes.

`asteroid.gd` caches irregular clipped stone plates at creation. Per-vertex rounded lighting, bevel lines and specular highlights create depth on the 2D canvas as the rock rotates. A new rock derives its material from its radius class; fragments inherit the parent's material. Damage overlays remain health-ratio driven.

`hit_asteroid()` removes a dead parent before rewarding it or creating fragments, so duplicate hits cannot multiply rewards. `fracture_asteroid()` creates two radius-31 pieces from a large rock, or two radius-20 pieces from a medium rock; small rocks stop the chain. Children use normal size/progression health, retain average parent velocity, get opposing lateral impulses, and start within the old footprint with initialized previous positions. They fly freely rather than restarting any boss tether. Swallowing calls `hit_asteroid(..., false)` to suppress fragments, while collision/escape cleanup uses `remove_asteroid()`. `tests/asteroid_fracture.gd` verifies these interactions and the finite seven-piece tree.

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
| Special stock, charge thresholds, preparation | `combat_controls.gd` |
| Single player-well duration | `player_well.lifetime_for_charge()` |
| Deflected ore damage and laser pressure | `game.resolve_deflected_rock()`, `game.reflected_laser()` |
| Death timing/shape/fire | `death_visual.gd`, `shaders/death_fire.gdshader` |
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
ALIEN_SAVE_PATH=/tmp/special-buttons-record.cfg godot --headless --path mobile --script res://tests/special_buttons.gd
ALIEN_SAVE_PATH=/tmp/combat-overhaul-record.cfg godot --headless --path mobile --script res://tests/combat_overhaul.gd
ALIEN_SAVE_PATH=/tmp/gravity-overhaul-record.cfg godot --headless --path mobile --script res://tests/gravity_overhaul.gd
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

`finish_run()` freezes gameplay and starts `DeathVisual.DURATION` (2.6 seconds). Menu buttons remain hidden throughout. The ship remains visible during normal recovery; gravity return changes only Y and does not blink or teleport the hull.

The sky shader receives one distant light vector shared by every body. Boss victory sets a new target direction and the visible illumination eases toward it gradually. No foreground suns are drawn.

Gravity expiry is evaluated before core/edge contact. Shielded contact must never return early forever and skip the expiration check. `tests/large_well_review.gd` covers this alongside maximum charge, freed actors, death animation, strict three-life loss and merged-well lifetime. `tests/large_well_stress.gd` runs a crowded maximum-charge encounter with real frame boundaries; it supports both headless and graphical execution.


## Render safety and destruction

`player_well.origins` and `combat.returns` use integer instance IDs, never Node keys. Resolve IDs with `instance_from_id()` only while updating gameplay, validate the result, and ignore queued/freed actors. The thrust drawing path iterates the live ship arrays only. A September 17 iPhone report showed a scene-update watchdog kill inside a GDScript redraw callback, with the gravity thrust validity/object-comparison/draw-line functions present. Avoid keeping destroyed actors in any render-loop iterator.

`death_visual.gd` reuses 240 textured hull triangles. Shared vertices bend and stretch coherently before panels snap apart. Shot deaths ignite immediately; impacts and white-edge deaths crush for 0.4 seconds first; black-hole fragments stretch and spiral into an opaque horizon. Every cause has a fire explosion and a strong smooth outward refraction wave that travels beyond the farthest screen corner before the menu appears. The horizon layer clips both fire and debris. `clear()` also hides the reusable fire surface, and degenerate swallowed triangles are skipped. `impact_visual.gd` pools four touch-transparent electrical contact surfaces.

Expired wells enqueue finite visual-only exit effects. Black exits contract two folds, collapse, then release outward energy; white exits release outward energy immediately with two expanding folds. The shield/escaped-alien shockwave is explicitly marked `visual_only` and cannot call any damage or force function. Keep it separate from the enemy-damaging mixed-hole annihilation.

## Motion, sound and distant scenery

`combat.update_attitudes()` turns the player and affected aliens against gravity, then eases them back upright. White resistance points the nose toward the field; black resistance points away. Tap cancellation still removes the force completely. Boss black pull rises gently from 66 to 86 pixels/second; white push falls from 118 to 94. These retain the former average displacement budget.

`curved_velocity()` preserves each weapon's speed while bending direction. Homing rockets steer gradually so their guidance does not erase curvature each frame. The laser uses the same force sampled along short rays at its own constant effective speed. `sound.update_gravity()` provides an artistic sound counterpart using a low-pass filter, subtle pitch change and stereo deflection; music is unaffected.

There are no foreground suns. One light vector is shared by all celestial bodies, easing toward a new sector direction rather than snapping. Planets are spaced by 3,160 logical pixels at the normal viewport height and vary from 65 to 235 pixels in radius. Ocean, gas, ice and rocky worlds use different surface palettes/patterns. Only some have moons or rings. Ring pixels are composited behind or in front according to their tilted plane coordinate. Colorful nebulae remain distant and slow.

`tests/gravity_polish.gd` covers the new combat and presentation contracts; `tests/polish_capture.gd` captures real GPU frames. `tests/device_gravity_probe.gd` is an isolated on-device harness that renders three maximum-charge fields with swallowed actors and writes progress to its own `user://gravity_probe.txt`. It is excluded from normal exports and uses its own save file. Copy it to a temporary export project as the main scene for device verification, then reinstall the normal playable pack.
