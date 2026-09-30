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

`defeat_boss()` pays score and calls `boss_drops()` once for exactly one special weapon, one primary upgrade and one shield. It copies an unfinished special into a detached boss node with `lingering = true`, then removes the actual boss. Existing shots and rocks also remain. Detached nodes render their attack without a boss body and free themselves instead of restarting a firefight.

Black/white bosses additionally leave a 1.8× core with an eight-second lifetime at the death position. Black death particles move inward; white particles move outward. The original well keeps its own position and remaining lifetime. One tap neutralises every active well; it never moves the ship.

`request_cruise_return()` sets one recovery flag after every player/boss gravity closure and boss victory. It removes any stale ship entry from `combat.returns`. Once **all** active fields end, the physics loop restores only cruising Y at 260 pixels/second; X remains under normal steering. This also applies above the screen midpoint and while a full shield is active. The director waits for residual attacks and recovery to finish.

## Weapons and damage

Weapon levels are 0 single, 1 double, 2 triple, 3 temporary laser, 4 enhanced triple plasma. Permanent upgrades skip 3. All primary fire uses 850 pixels/second and 0.17-second cadence: normal bullets deal one damage, level 4 deals two. `combat.collect_laser()` banks a charge up to 99. `activate_laser()` selects or deselects a ten-second held-firing budget, preserving unused time. Expiry restores `previous_weapon` without consuming another charge. Permanent pickups improve that remembered tier while a laser is active. Cannons are separate inventory, travel at 660 pixels/second and deal three direct/splash damage.

The laser is one persistent visual node. Its trace has at most 384 eight-pixel gravity-curved steps and three asteroid reflections. Small aliens die on contact; an unguarded boss loses one health per 0.25 seconds of continuous exposure. Boss hull/shield surfaces absorb the beam with an animated contact glow. Asteroids reflect it away from the player and receive `180 * (20/radius)^2 * delta` momentum, bounded to 550 pixels/second. Preview traces use delta zero and cannot alter physics. Filled animated ribbons replace the old polylines. `visible_shot_intersects()` clips each shot/beam segment to the actual playfield before testing the target circle; visible portions of edge targets work, while entirely offscreen contacts and boss arrival damage remain blocked.

The ship draws wider hulls and matching barrels for each upgrade. Its collision radius stays small and constant so an upgrade does not make dodging unexpectedly harder. New shapes belong in `ship._draw()`; projectile muzzle positions belong in `weapon_system.fire()`.

## Touch controls, fatal hazards and player gravity

`combat_controls.gd` owns one steering pointer plus independent targeting taps in `aim_touches`. Holding the ship/lower region fires; dragging steers; release or leaving the viewport stops control. `interface.route_special_touch()` handles each button pointer explicitly before GUI mouse emulation can steal a second finger. `_input()` routes owned releases once. Enemy taps consume one shared cannon; the button requires at least five for a small-alien volley and allocates only needed available ammunition, nearest escape first, reserving damage from cannons already in flight. A boss tap fires one cannon; `boss_cannon_in_flight()` gates both input methods until that targeted shot resolves. With no exposed small aliens the button can fire one at the boss with any positive stock. Start stock is 30, drops add five, cap 99. Blast radius is 65 pixels.

`add_gravity_charge()` banks eligible alien kills from 0 to 50. Ten unlock the button. `arm_gravity()` starts a three-second selection window; pressing it again cancels. Only safe upper-half taps select a target. Their release reserves charge and starts a fresh one-third-second particle/refraction preparation, even if selected just before the automatic deadline. Existing steering remains owned, and fresh lower-half touches can steer while armed.

Without a selected target, the automatic shot launches at exactly three seconds toward `(arena.x * 0.5, arena.y * 0.25)`. `gravity_preparation_time()` exposes the final third-second of the selection window to the particle and warp renderers without reserving or spending charge early. A rare shielded ship occupying the default destination makes `automatic_gravity_target()` choose a safe upper-half alternative. `queue_gravity()` fixes the size/target; `launch_gravity()` alone consumes the reservation and fires at 1225 pixels/second. Ordinary steering release does not cancel it; pause, death, restart, or newly active unshielded gravity does, without spending charge. A full shield permits counterattacks. `player_well.lifetime_for_charge()` maps charge factors 1–5 to 3–7.5 seconds; `scale_for_charge()` maps that range linearly to a smaller 0.9–1.35 core scale. Pull strength stays independent of charge. Hole absorption and safe annihilation call `destroy_enemy(enemy, false)` to prevent self-funding gravity chains.

Player wells store pre-pull positions only for surviving non-player actors. Ship recovery always uses the cruising-height path; asteroids keep changed velocity and never return to their old positions. Bosses stay outside player horizons through `update_player_well_dodge()`, using a persistent escape direction and smoothly filtered velocity instead of choosing a new grid cell each frame. Targets can leave any viewport edge. `player_well_threats()` includes pending shots and incoming payloads; `safe_dodge_segment()` checks the return path and `continuous_dodge_clearance()` handles a field growing across the hull. All active-core clearance uses `gravity_fields.core_radius()`, including during coalescence. Their gravity-only warp does not block ordinary damage. Taps fully neutralise every active field without moving the ship or firing.

`combat.hazards_protected()` means either forced tapping or a collected full shield. The automatic ward deflects incoming shots and rocks and zaps small aliens near its dome, but cores and white edges remain lethal. The ten-second pickup shield additionally allows movement, firing and gravity immunity. Outside protection, asteroid/doom-cannon contact is instant loss; ordinary fire and alien collision cost one hull. `shield_zap_if_close()` sweeps each alien path before the escape rule and triggers once its visible hull reaches one pixel beyond `combat.shield_radius()`. `zap_alien()` emits a branching bolt from the dome plus a local shield ripple, then destroys the alien. Outside protection, `handle_alien_collision()` waits for contact before emitting the electrical discharge and losing one life. Lives refill to a maximum of three, and upgrades never revive the player. Support drops first have a 25% cannon chance; remaining rewards choose hull/shield at 75%/25%, preserving the 3:1 hull/shield ratio.

`asteroid.player_deflected` is set only after player-hole, shield/ward or laser momentum changes. `resolve_deflected_rock()` kills small aliens or applies three damage to a boss (guard gate respected), then shatters the rock once. Ambient rocks cannot damage enemies; fragments inherit ownership. Gravity still permanently changes rock trajectories.

`combat.vibrate()` uses a rate-limited enemy-death tick, a continuous low-amplitude gravity rumble and a double hit pulse. Black-hole spawning adds a single pop; white-hole spawning schedules three irregular pops before the rumble. Enemy feedback never clears and restarts the active gravity rumble: doing so flooded the iOS haptic engine and stalled touch delivery during dense fights. The queue is bounded and muted by the saved vibration preference independently of sound. `interface.activate_special()` calls `weapon_button_feedback()` only after an accepted action: gravity arm/cancel, laser toggle, a nonempty cannon volley or a successful electron chain. Each emits one short, distinct pulse; frame updates and held fingers cannot repeat it. If a click interrupts a gravity rumble, the controller resumes that rumble after the finite click. `weapon_feedback_requested` observes the same branch for deterministic input tests. Godot's `Input.vibrate_handheld` supplies the physical feedback; evaluate its feel on the device.

The title and pause menus persist three accessibility presentation controls through `progress.gd`: screen shake on/off, reduced/full laser brightness, and reduced/full gravity distortion. `space_folds.gd` feeds shield volumes, tap pulses, mixed-hole shockwaves, exit waves, boss shields, holes, and tethers into one bounded screen-reading pass. This keeps the effect visually consistent and caps the number of simultaneous lenses.

Characters and combat effects remain 2D. The collected shield combines exaggerated refraction with a transparent blue hexagonal shell, shifting color and electrical flow. `combat.gravity_touches` tracks real held pointers separately: resistance shows only the old concentrated warp, immediately cleared on release, cancellation or pointer exit. A hold never repeats neutralisation. The collected dome is visible only while `shield_time > 0`, exactly matching immunity. `shield_dome.gdshader` reduces the diffuse halo to 10% of its former brightness while keeping the mesh and flowing highlights brighter. The background distortion amplitude is retained; reducing the cosmetic haze must not silently weaken the physics or lens. Hostile bullets curve around the shield without being absorbed. The escaped-alien doom cannon is the deliberate exception: the shield absorbs it and emits a harmless outward ripple. The white-hole boundary shader follows the safe-area corner shape on iPhone and uses square desktop corners. Every white exit discharges this bubble with light. Black cores mask all actors and death fragments. Blue player disks and encounter-colored alien disks have shader particles whose inward/outward motion and spin match the accretion flow.

`accretion_visual.gd` and `accretion.gdshader` animate the committed luminance texture in `assets/effects/`. The image's black backdrop becomes transparent via sampled luminance; colour mapping supplies blue, alien, or white plasma. Two texture samples provide rotation and radial flow on each quad, with the simulation clock freezing animation during pause. `gravity_interactions.gd` reuses at most twelve sprites at layer -5 behind ships, then masks every actual core at layer 32 above ships and death fragments. The outer extent scales more slowly than core size to limit maximum-charge overdraw. Restart hides the pool rather than creating more nodes. Active well refraction has strength 1.4 and takes priority over cosmetic pulses in the eight-lens budget. `tests/accretion_capture.gd` verifies rendered core opacity, animation, actual refraction and lens priority.

`hull_finish.gd` provides the shared painted metal treatment for ships and bosses. Vertex colours shade each raised plate, opposite bevels have different brightness, and a slowly moving band simulates a reflection. Bright metal faces remain legible over space, while thin dark separators preserve silhouettes over planets. This helper has no gameplay state and creates no render nodes.

`asteroid.gd` caches irregular clipped stone plates at creation. Per-vertex rounded lighting, bevel lines and specular highlights create depth on the 2D canvas as the rock rotates. A new rock derives its material from its radius class; fragments inherit the parent's material. Damage overlays remain health-ratio driven.

`hit_asteroid()` removes a dead parent before rewarding it or creating fragments, so duplicate hits cannot multiply rewards. `fracture_asteroid()` creates two radius-31 pieces from a large rock, or two radius-20 pieces from a medium rock; small rocks stop the chain. Children use normal size/progression health, retain average parent velocity, get opposing lateral impulses, and start within the old footprint with initialized previous positions. They fly freely rather than restarting any boss tether. Swallowing calls `hit_asteroid(..., false)` to suppress fragments, while collision/escape cleanup uses `remove_asteroid()`. `tests/asteroid_fracture.gd` verifies these interactions and the finite seven-piece tree.

Large roots (`radius >= 37`) create a shared `reward_family` dictionary with `remaining`, `eligible` and `rewarded` fields. Both children inherit the same dictionary at each fracture. Only positive damage tagged `"primary"`—ordinary gun bullets or enhanced plasma—preserves eligibility. Non-primary damage on any ancestor or descendant invalidates the entire family, even when that hit is not lethal. Escape, collision removal and swallowed pieces also invalidate it; deflection without damage does not. Parent removal decrements the live count, then child creation increments it before `finish_asteroid_family()` checks completion. A zero-count eligible family produces exactly one special (30% electron, otherwise laser) at the last piece, replacing the oldest pickup if needed. The `rewarded` guard and actor-list membership prevent same-frame duplicate payouts. Standalone medium/small rocks never start this bonus.

## Tuning map

| Change | Location |
| --- | --- |
| Boss health curve, alien/rock health, wave timing | `game.gd`: spawn/director methods |
| Shooting frequency | `difficulty_scale()` and its callers |
| Ten-alien support drops and exact boss rewards | `guaranteed_drop()`, `maybe_drop_pickup()`, `boss_drops()` |
| Gravity force, tap duration and attack length | `boss.gd` constants and `step()` |
| Smooth return speed | `game._physics_process()` |
| Laser contact duration and boss damage | `game.update_laser()` |
| Bullet patterns/speed | `weapon_system.gd` |
| Special stock, charge thresholds, auto-target timer, button feedback | `combat_controls.gd` |
| Smooth offscreen boss avoidance | `boss.update_player_well_dodge()` |
| Large-asteroid completion bonus | `game.hit_asteroid()`, `fracture_asteroid()`, `finish_asteroid_family()` |
| Shield proximity threshold and zap | `game.shield_zap_if_close()`, `impact_visual.play_zap()` |
| Liquid merge geometry and live core radius | `gravity_interactions.gd`, `blackhole_coalescence.gdshader` |
| Single player-well size and duration | `player_well.scale_for_charge()`, `lifetime_for_charge()` |
| Deflected ore damage and laser pressure | `game.resolve_deflected_rock()`, `game.reflected_laser()` |
| Death timing/shape/fire | `death_visual.gd`, `shaders/death_fire.gdshader` |
| Ship appearance | `ship.gd` |
| Boss shield orbit size/speed | `game.update_enemies()` |
| Sound pitch, duration and volume | `sound.gd` |
| Planet travel, colors, stars | `shaders/space_background.gdshader` |
| Fold distortion | `space_folds.gd` and its matching shader |

Health progression: small aliens always take 3 normal bullet damage, with wreckage after one hit and smoke after two. Rocks start at 5/8/12 by size and gain one every two victories. Bosses use `floor(100 - 780 / (12 + victories))`, capped at 99. The underlying curve starts at 35 and approaches 100. Difficulty begins at 1%; the 50% reference is used for firing. Regular loot now follows exactly one pickup per ten defeated small aliens, counted across swarms.

## Audio and rendering performance

Sounds are synthesized once and cached, not rebuilt for every shot. Regular effects share a small voice pool. Ship hits and gravity/death impacts use dedicated voices; the laser uses a looping electric channel. Pause and mute must stop every applicable channel. Volumes are decibels: a less-negative value is louder.

Ordinary bullet geometry is cached while the node moves. Only animated beam/rocket graphics request repeated redraws. Particles cap at 256 and pickups at 12. Preserve those bounds when adding effects. Background refraction has fixed capacities of eight lenses and six strands; change both controller and shader together if adjusting them. Draw order keeps HUD and actors sharp above the distorted background.

## Tests, saves and mobile builds

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

For Android, the committed `Android` preset exports a debug-signed APK for ARMv7 and ARM64 without a custom Gradle build. Configure matching Godot export templates, a supported Android SDK/JDK and the local debug keystore in the editor first. From the repository root:

```sh
mkdir -p build/android
godot --headless --path mobile --export-debug Android ../build/android/AlienInvasion-debug.apk
```

It enables vibration, disables internet permission and user-data backup, and uses the same package ID as iOS. This command creates a test package; it does not validate Android hardware or configure private release signing/Google Play AAB distribution. Keep keystores and generated artifacts outside Git.

## The original Python version

`alien_invasion.py` owns a 60 FPS Pygame loop. `settings.py` holds its separate tuning values; `ship.py`, `alien.py`, and `bullet.py` are actors. `game_stats.py`, `scoreboard.py`, and `button.py` handle state and display. Unlike the Godot version, this older code uses per-frame movement and does not save its high score to disk. Its existing method docstrings and added module comments explain these differences.

Godot 4.7’s iOS haptic implementation can log “Could not vibrate using haptic engine: (null)” even when feedback succeeds. This is an upstream logging bug, not a failed game assertion: https://github.com/godotengine/godot/issues/121614. The actual vibration feel still needs hands-on testing.

## Interacting fields and readable defeat

`gravity_interactions.gd` updates active fields before actor physics. Black fields attract at a bounded rate, join through an opaque liquid neck, and form one field using `sqrt(radius_scale_a² + radius_scale_b²)` and the sum of their **remaining** seconds. This keeps the launch charge cap separate from conserved merged area and duration. During approach, `update_coalescence_shapes()` pairs nearby black horizons once each. `droplet_radii()` uses a bounded eight-step area search so overlapping lobes swell without losing their combined visible disc area. `blackhole_coalescence.gd` reuses a shader quad to round the connecting neck above actor rendering. `core_radius(well)` is the shared live radius for swallowing, projectiles, beam routing, visuals, engine proximity and boss clearance; use it instead of recalculating `31 * well_scale`. The original `well_scale` remains the mass used at final merge. Coalescence removes the consumed field without an expiry pulse or false recovery kick. A player field owns the merged field when present so survivor bookkeeping is retained. All interacting fields pause their lifetime clocks. White centers repel while expanding pressure fronts eventually meet and discharge both fields; the surviving single field resumes its clock. When multiple white fields exist, proximity raises force by up to 3× and shortens the neutralisation window by the same factor. Taps always cancel force completely.

Opposite cores cancel on contact, show a 0.35-second flash, then emit a local shockwave. It destroys nearby exposed aliens, deals five damage to exposed rocks/bosses, and clears nearby shots. It never calls player damage. Existing boss shields still gate boss damage.

Defeated tractor bosses leave a damaged glowing core at the original tether origin. The existing barrage finishes without being restarted, then the core burns out. Its strands retain background distortion.

`finish_run()` freezes gameplay and starts `DeathVisual.DURATION` (2.6 seconds). Menu buttons remain hidden throughout. The ship remains visible during normal recovery; gravity return changes only Y and does not blink or teleport the hull.

The sky shader receives one distant light vector shared by every body. Boss victory sets a new target direction and the visible illumination eases toward it gradually. No foreground suns are drawn.

Gravity expiry is evaluated before core/edge contact. Shielded contact must never return early forever and skip the expiration check. `tests/large_well_review.gd` covers this alongside maximum charge, freed actors, death animation, strict three-life loss and merged-well lifetime. `tests/large_well_stress.gd` runs a crowded maximum-charge encounter with real frame boundaries; it supports both headless and graphical execution.


## Render safety and destruction

`player_well.origins` and `combat.returns` use integer instance IDs, never Node keys. Resolve IDs with `instance_from_id()` only while updating gameplay, validate the result, and ignore queued/freed actors. The thrust drawing path iterates the live ship arrays only. A September 17 iPhone report showed a scene-update watchdog kill inside a GDScript redraw callback, with the gravity thrust validity/object-comparison/draw-line functions present. Avoid keeping destroyed actors in any render-loop iterator.

`death_visual.gd` reuses 240 textured hull triangles. Shared vertices fold inward coherently before panels snap apart; `strained_vertex()` clamps each initial offset inside its original radius, preventing elastic outward growth during the collapse. Cause-specific compression axes distinguish `shot`, `asteroid`, `ram`, `black` and `white` deaths (`impact` remains a compatibility alias). `ignition_delay()` gives shots a quick 0.14-second buckle, asteroid contact 0.34 seconds and other causes 0.4 seconds. Black fragments subsequently spiral into the opaque horizon, while a white-edge death compresses toward the boundary. The existing post-ignition fire explosion, outward debris and strong smooth refraction wave still travel beyond the farthest screen corner before the menu appears. The horizon layer clips both fire and debris. `clear()` also hides the reusable fire surface, and degenerate swallowed triangles are skipped. `impact_visual.gd` pools four touch-transparent electrical contact surfaces and provides `play_zap(from, to)` for a short branching shield bolt. These visual surfaces do not own input or apply damage.

Expired wells enqueue finite visual-only exit effects. Black exits contract two folds, collapse, then release outward energy; white exits release outward energy immediately with two expanding folds. The shield/escaped-alien shockwave is explicitly marked `visual_only` and cannot call any damage or force function. Keep it separate from the enemy-damaging mixed-hole annihilation.

## Motion, sound and distant scenery

`combat.update_attitudes()` turns the player and affected aliens against gravity, then eases them back upright. White resistance points the nose toward the field; black resistance points away. Tap cancellation still removes the force completely. Boss black pull rises gently from 66 to 86 pixels/second; white push falls from 118 to 94. These retain the former average displacement budget.

`curved_velocity()` preserves each weapon's speed while bending direction. Homing rockets steer gradually so their guidance does not erase curvature each frame. The laser uses the same force sampled along short rays at its own constant effective speed. `sound.update_gravity()` provides an artistic sound counterpart using a low-pass filter, subtle pitch change and stereo deflection; music is unaffected.

There are no foreground suns. One light vector is shared by all celestial bodies, easing toward a new sector direction rather than snapping. Planets are spaced by 3,160 logical pixels at the normal viewport height and vary from 65 to 235 pixels in radius. Ocean, gas, ice and rocky worlds use different surface palettes/patterns. Only some have moons or rings. Ring pixels are composited behind or in front according to their tilted plane coordinate. Colorful nebulae remain distant and slow.

`tests/gravity_polish.gd` covers the new combat and presentation contracts; `tests/polish_capture.gd` captures real GPU frames. `tests/device_gravity_probe.gd` is an isolated on-device harness that renders three maximum-charge fields with swallowed actors and writes progress to its own `user://gravity_probe.txt`. It is excluded from normal exports and uses its own save file. Copy it to a temporary export project as the main scene for device verification, then reinstall the normal playable pack.


## Glass controls, electron chains and visible damage

The four circular controls on the right use `interface.route_special_touch()` and ignore Godot's rectangular GUI mouse hit regions. A finger that already owns steering retains it when crossing an icon; only a fresh press inside the circular control can activate it. Releasing a button outside its circle cancels that press. The old top HUD and gravity instruction text are removed. `playfield_top()` is zero: safe-area padding is for controls only, never a boundary for input, bullets, laser hits or gravity. An armed gravity button adds a touch-transparent target guide via `interface.draw_gravity_target()`.

Bosses drop exactly one special (30% electron, otherwise laser), one gun upgrade and one shield. A primary-gun-only large-asteroid family earns one special on its final fragment; it does not receive the other two boss drops. Ordinary swarms drop support items and primary upgrades only. `electron_stock` caps at 10, laser stock at 99, and cannon stock at 99. `electron_beam.gd` chooses the visible alien nearest the gun's X column, then walks nearest neighbors. Asteroids melt without fragmenting; the boss is visited last and receives one cannon-equivalent hit, subject to its guard gate. Every target ID is checked again before damage. Failed or empty activations do not spend inventory.

`energy_optics.gd` provides analytic swept core intersections and finite tangent/arc detours. Black fields capture matter into constant-speed inward spirals; homing is disabled after capture. White fields curve shots smoothly outside a safety margin around the core. Collision uses the curved subsegments, not a chord through the center. Lasers use a single continuous trace, strongly bent outside black horizons and absorbed on contact, or deflected around white cores. Damage remains one exposure counter per actor. Gravity payloads detonate at existing horizons so merges and annihilation still occur. The optical path has hard iteration and geometry budgets.

After the last field closes, `request_cruise_return(departing_force)` schedules 0.24 seconds of decaying thrust recoil. The kick is clamped inside the playfield and protected from lethal contact; the subsequent cruise return changes only Y. New fields suspend recovery. Resultant gravity vectors determine movement and nose direction when multiple fields overlap.

`boss_collapse.gd` snapshots a defeated gravity hull and deforms it into its larger death well after 0.65 seconds. The original unfinished attack is detached separately with its scale and remaining lifetime preserved. Restart clears all pending transformations.

Shield geometry uses `combat.shield_radius()` so every upgraded wingspan fits inside the requested 20% larger envelope. `shield_visual.gd` owns shell activation, hit ripples and dissipation. Damage helpers change only rendered hulls and smoke; three-hit alien durability and player lives remain in the game controller, while actual movement/collision geometry stays unchanged. A swarm shares one emissive color.

`space_background.gd` renders the stationary stars behind transparent celestial art in a single reusable SubViewport. `space_folds.gd` refracts that complete texture and nearby solar wind; distant stars are optically warped along with everything else. Planet atmosphere, moon tides/fragments and nebula response are subtle and stop with the field. Solar wind varies smoothly between near-zero, light, moderate and intense sectors. Its renderer now uses smooth clouds at 10% of the previous particle brightness; the fixed shader workload avoids a growing particle pool. The white boundary has one-third its earlier optical width.

Current integration checks:

```sh
ALIEN_SAVE_PATH=/tmp/next-combat-record.cfg godot --headless --path mobile --script res://tests/next_combat.gd
ALIEN_SAVE_PATH=/tmp/glass-controls-record.cfg godot --headless --path mobile --script res://tests/glass_controls.gd
ALIEN_SAVE_PATH=/tmp/gravity-resolution-record.cfg godot --headless --path mobile --script res://tests/gravity_resolution.gd
ALIEN_SAVE_PATH=/tmp/weapon-button-timing-record.cfg godot --headless --path mobile --script res://tests/weapon_button_timing.gd
ALIEN_SAVE_PATH=/tmp/dodge-coalescence.cfg godot --headless --path mobile --script res://tests/dodge_coalescence.gd
ALIEN_SAVE_PATH=/tmp/asteroid-rewards-zaps-record.cfg godot --headless --path mobile --script res://tests/asteroid_rewards_zaps.gd
```

## Full-screen gravity ripples

`gravity_interactions.force_from_well()` is shared by physical movement and the ripple clock. `advance_ripples()` integrates **3 × the capped unresisted speed at the ship × delta**, wraps after `RIPPLE_WAVELENGTH` (112 logical pixels), and removes expired instance IDs. Each overlapping well uses its own force, so opposed fields retain visible waves even when their net movement cancels. This clock advances once per physics step and ignores tap/shield cancellation; pause stops it.

`space_folds.gd` passes those phases in `wave_distances[8]` and sizes each active lens to include every screen corner, even if the source is offscreen. Its shader uses circular radial phase: positive travel outward for white, negative travel inward for black. Refraction fades as `(1 + distance / 155)^-1.15`, retaining subtle far-screen motion and the existing local spiral throat. The eight-lens budget and fixed texture samples remain unchanged; larger coverage adds no particles or nodes.

`electron_beam.gd` advances a visible tip at 340 logical pixels/second with bounded wavy plasma meshes and contact sparks. Every target is revalidated on arrival; no damage is dealt ahead of the stream. Black horizons stop the entire remaining chain. Trails and sparks have fixed capacities and are cleared on restart.

Focused regression checks:

```sh
ALIEN_SAVE_PATH=/tmp/gravity-paths-record.cfg godot --headless --path mobile --script res://tests/gravity_paths.gd
ALIEN_SAVE_PATH=/tmp/electron-stream-record.cfg godot --headless --path mobile --script res://tests/electron_stream.gd
ALIEN_SAVE_PATH=/tmp/lake-ripples-record.cfg godot --headless --path mobile --script res://tests/lake_ripples.gd
```

For GPU verification, set `ALIEN_CAPTURE_DIR` to an existing directory and omit `--headless` for `lake_ripples.gd` or `electron_stream.gd`. `restored_refraction.gd` requires the real renderer, that directory and `/tmp/refraction-record.cfg`; it compares actual distant-star pixels and verifies collected-shield expiry versus held-finger warp visibility.
